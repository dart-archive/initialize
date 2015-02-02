// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.plugin_transformer;

import 'dart:async';
import 'package:analyzer/analyzer.dart';
import 'package:barback/barback.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

/// Abstract transformer which will call [initEntry] for every [InitEntry]
/// expression found in the bootstrap file. This is used to centralize logic
/// for initializers which want to do something special at transform time.
abstract class InitializePluginTransformer extends AggregateTransformer {
  // Path to the bootstrap file created by the initialize transformer.
  final String _bootstrapFile;

  // All the extra assets that were found, if child classes override
  // classifyPrimary this lets them get at the other assets easily.
  final allAssets = <Asset>[];

  TransformLogger _logger;

  InitializePluginTransformer(this._bootstrapFile);

  classifyPrimary(AssetId id) =>
      _bootstrapFile == id.path ? _bootstrapFile : null;

  Future apply(AggregateTransform transform) {
    _logger = transform.logger;
    var listener = transform.primaryInputs.listen((Asset asset) {
      allAssets.add(asset);
      var id = asset.id;
      if (id.path != _bootstrapFile) return;
      // Calls initEntry for each InitEntry expression.
      asset.readAsString().then((dartCode) {
        var url = id.path.startsWith('lib/')
            ? 'package:${id.package}/${id.path.substring(4)}'
            : id.path;
        var source = new SourceFile(dartCode, url: url);
        var transaction = new TextEditTransaction(dartCode, source);
        (parseCompilationUnit(dartCode,
                    suppressErrors: true) as dynamic).declarations.firstWhere(
                (d) => d.name.toString() ==
                    'main').functionExpression.body.block.statements.firstWhere(
            (statement) {
          return statement.expression.target.toString() == 'initializers' &&
              statement.expression.methodName.toString() == 'addAll';
        }).expression.argumentList.arguments[0].elements
            .where((arg) => arg is InstanceCreationExpression)
            .forEach((e) => initEntry(e, transaction));

        // Apply any transformations.
        if (!transaction.hasEdits) {
          transform.addOutput(asset);
        } else {
          var printer = transaction.commit();
          printer.build(url);
          transform.addOutput(new Asset.fromString(id, printer.text));
        }
      });
    });

    // Make sure all the assets are read before returning.
    return listener.asFuture();
  }

  /// Gets called once for each generated [InitEntry] expression in the
  /// bootstrap file. A [TextEditTransaction] is supplied so that the user can
  /// modify the expression however they see fit.
  void initEntry(
      InstanceCreationExpression expression, TextEditTransaction transaction);

  /// Convenience method to delete an Initializer expression completely.
  void removeInitializer(
      InstanceCreationExpression expression, TextEditTransaction transaction) {
    // Delete the entire line.
    var line = transaction.file.getLine(expression.offset);
    transaction.edit(transaction.file.getOffset(line),
        transaction.file.getOffset(line + 1), '');
  }
}
