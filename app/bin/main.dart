import 'dart:convert';
import 'dart:io';

import 'package:app/github.dart';
import 'package:app/inputs.dart';
import 'package:meta/meta.dart';
import 'package:app/pana_result.dart';

dynamic main(List<String> args) async {
  exitCode = 0;

  // Parsing user inputs and environment variables
  final Inputs inputs = Inputs();

  final Analysis analysis = await Analysis.queue(
    commitSha: inputs.commitSha,
    githubToken: inputs.githubToken,
    repositorySlug: inputs.repositorySlug,
  );

  Future<void> tryCancelAnalysis(dynamic cause) async {
    try {
      await analysis.cancel(cause: cause);
    } catch (e, s) {
      _writeError(e, s);
    }
  }

  Future<void> _exitProgram([dynamic cause]) async {
    await tryCancelAnalysis(cause);
    await Future.wait<dynamic>([stderr.done, stdout.done]);
    stderr.writeln('Exiting with code $exitCode');
    exit(exitCode);
  }

  try {
    // Command to disable analytics reporting, and also to prevent a warning from the next command due to Flutter welcome screen
    await _runCommand('flutter', const <String>['config', '--no-analytics']);

    await analysis.start();

    // Executing the analysis
    stderr.writeln('Running pana...');
    final panaProcessResult = await _runCommand(
      'pana',
      <String>[
        '--scores',
        '--no-warning',
        '--source',
        'path',
        inputs.paths.canonicalPathToPackage,
      ],
    );

    if (panaProcessResult.exitCode != 0) {
      stderr.writeln('Pana exited with code ${panaProcessResult.exitCode}');
      exitCode = panaProcessResult.exitCode;
      await _exitProgram();
    }
    if (panaProcessResult.output == null) {
      throw Exception('The pana command has returned no valid output.'
          ' This should never happen.'
          ' Please file an issue at https://github.com/axel-op/dart-package-analyzer/issues/new');
    }

    final panaResult = PanaResult.fromOutput(
      jsonDecode(panaProcessResult.output) as Map<String, dynamic>,
      paths: inputs.paths,
    );

    // Posting comments on GitHub
    await analysis.complete(
      panaResult: panaResult,
      minAnnotationLevel: inputs.minAnnotationLevel,
    );

    // Setting outputs
    await _setOutput('health', panaResult.healthScore.toStringAsFixed(2));
    await _setOutput(
        'maintenance', panaResult.maintenanceScore.toStringAsFixed(2));
    await _setOutput('errors', panaResult.analyzerResult.errorCount.toString());
    await _setOutput(
        'warnings', panaResult.analyzerResult.warningCount.toString());
    await _setOutput('hints', panaResult.analyzerResult.hintCount.toString());
  } catch (e) {
    //_writeErrors(e, s); // useless if we rethrow it
    await tryCancelAnalysis(e);
    rethrow;
  }
}

/// Set an output for this Action.
/// This output will be available for subsequent steps in the workflow.
Future<void> _setOutput(String key, String value) async {
  await _runCommand('echo', ['::set-output name=$key::$value']);
}

/// Runs a command and prints its outputs to stderr and stdout while running.
/// Returns a [_ProcessResult] with the sdtout output in a String.
Future<_ProcessResult> _runCommand(
  String executable,
  List<String> arguments, {
  bool getStderr = false,
}) async {
  final streamsToFree = <Future<dynamic>>[];
  final Future<List<dynamic>> Function() freeStreams =
      () async => Future.wait<dynamic>(streamsToFree);
  try {
    final process =
        await Process.start(executable, arguments, runInShell: true);
    final Stream<List<int>> errStream = process.stderr.asBroadcastStream();
    streamsToFree.add(stderr.addStream(errStream));
    final Stream<List<int>> outStream = process.stdout.asBroadcastStream();
    streamsToFree.add(stdout.addStream(outStream));
    final Future<List<String>> outputStderr =
        errStream.transform(utf8.decoder).toList();
    final Future<List<String>> outputStdout =
        outStream.transform(utf8.decoder).toList();
    final code = await process.exitCode;
    await freeStreams();
    final output = StringBuffer();
    if (getStderr) output.writeln((await outputStderr)?.join());
    output.write((await outputStdout)?.join());
    return _ProcessResult(exitCode: code, output: output.toString());
  } catch (e) {
    await freeStreams();
    rethrow;
  }
}

void _writeError(dynamic error, StackTrace stackTrace) {
  stderr.writeln(error.toString() +
      (stackTrace != null ? '\n' + stackTrace.toString() : ''));
}

class _ProcessResult {
  final String output;
  final int exitCode;

  _ProcessResult({
    @required this.exitCode,
    @required this.output,
  });
}
