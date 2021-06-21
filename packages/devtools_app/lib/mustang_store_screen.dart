import 'package:devtools_app/src/common_widgets.dart';
import 'package:devtools_app/src/eval_on_dart_library.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/screen.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';
import 'package:flutter_json_widget/flutter_json_widget.dart';

Future<List<Map<String, dynamic>>> getStoreData() async {
  final evalOnDartLibrary = EvalOnDartLibrary(
    ['package:mustang_core/src/state/wrench_store.dart'],
    serviceManager.service,
  );

  final InstanceRef mustangeStoreRef = await evalOnDartLibrary.safeEval(
    'WrenchStore.storeState()',
    isAlive: Disposable(),
  );

  //http://127.0.0.1:54139/jZnlZzWoYxI=/#/vm

  final Instance mustangStore =
      await evalOnDartLibrary.getInstance(mustangeStoreRef, Disposable());

  final List<dynamic> storeElements = mustangStore.elements;
  final List<Map<String, dynamic>> storeData = [];

  for (var i = 0; i < storeElements.length; i++) {
    final Instance eleRef =
        await evalOnDartLibrary.getInstance(storeElements[i], Disposable());
    final Map<String, dynamic> data = eleRef.toJson();
    final Map<String, dynamic> requiredData = {
      'className': data['class']['name'],
      'fields': data['fields']
          .map((e) => {
                'name': e['decl']['name'],
                'value': e['value']['valueAsString'],
              })
          .toList(),
    };
    storeData.add(requiredData);
    // storeData.add(data);
  }

  return storeData;
}

class MustangStoreScreen extends Screen {
  const MustangStoreScreen()
      : super.conditional(
          id: id,
          // The name of the package that needs to be
          // included in the inspected application
          requiresLibrary: 'package:mustang_core',
          title: 'Mustang Store',
          icon: Icons.run_circle,
        );

  static const id = 'example';

  @override
  Widget build(BuildContext context) {
    return const StoreScreen();
  }
}

class StoreScreen extends StatefulWidget {
  const StoreScreen({Key key}) : super(key: key);

  @override
  _StoreScreenState createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  Map<String, dynamic> _modelData;
  Widget _body = Container();

  @override
  void initState() {
    super.initState();
    setState(() {
      _body = FutureBuilder(
        future: getStoreData(),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<Map<String, dynamic>>> storeData,
        ) {
          final List<Map<String, dynamic>> data = storeData?.data;
          return ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: data?.length ?? 0,
            itemBuilder: (BuildContext _, index) {
              String className = data[index]['className'];
              // String className = data[index]['class']['name'];
              if (className.contains('\$')) {
                className = className.split('\$')[1];
              }
              return Padding(
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(
                        5.0,
                      ),
                    ),
                    color: Theme.of(context).primaryColor,
                  ),
                  child: ListTile(
                    onTap: () => setModelData(data[index]),
                    title: Text(
                      className,
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    });
  }

  void setModelData(Map<String, dynamic> modelData) {
    setState(() {
      _modelData = modelData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          width: 400,
          child: Column(
            children: <Widget>[
              IconLabelButton(
                onPressed: () => setState(() {
                  _body = FutureBuilder(
                    future: getStoreData(),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<List<Map<String, dynamic>>> storeData,
                    ) {
                      final List<Map<String, dynamic>> data = storeData?.data;
                      return ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: data?.length ?? 0,
                        itemBuilder: (BuildContext _, index) {
                          String className = data[index]['className'];
                          // String className = data[index]['class']['name'];
                          if (className.contains('\$')) {
                            className = className.split('\$')[1];
                          }
                          return Padding(
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(
                                    5.0,
                                  ),
                                ),
                                color: Theme.of(context).primaryColor,
                              ),
                              child: ListTile(
                                onTap: () => setModelData(data[index]),
                                title: Text(
                                  className,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }),
                icon: Icons.refresh,
                label: 'Fetch From Store',
                includeTextWidth: 750,
              ),
              const SizedBox(
                height: 10.0,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: _body,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: _modelData == null
                      ? const Center(
                          child: Text('Select a model to see its contents'),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: _dataViewer(_modelData),
                            // [JsonViewerWidget(_modelData)],
                          ),
                        ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }

  List<Widget> _dataViewer(Map<String, dynamic> modelData) {
    String className = modelData['className'];
    if (className.contains('\$')) {
      className = className.split('\$')[1];
    }
    final List<Widget> modelDataWidgets = [
      Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
        ),
        child: ListTile(
          title: Text(
            '$className',
            style: Theme.of(context).textTheme.headline5,
          ),
        ),
      ),
    ];
    modelData['fields'].forEach(
      (e) {
        return modelDataWidgets.add(
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
            ),
            child: ListTile(
              title: Text(
                '${e["name"]}',
              ),
              subtitle: Text('${e["value"]}'),
            ),
          ),
        );
      },
    );
    return modelDataWidgets;
  }
}
