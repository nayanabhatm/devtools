import 'dart:async';

import 'package:devtools_app/src/common_widgets.dart';
import 'package:devtools_app/src/eval_on_dart_library.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/screen.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';
import 'package:flutter_json_widget/flutter_json_widget.dart';

// garbage collector issue: https://github.com/dart-lang/sdk/blob/master/runtime/vm/service/service.md

const List<String> primitiveDataType = ['bool', 'int', 'double', 'String'];

Future<List<Map<String, dynamic>>> getStoreData() async {
  final evalOnDartLibrary = EvalOnDartLibrary(
    ['package:mustang_core/src/state/wrench_store.dart'],
    serviceManager.service,
  );

  final InstanceRef mustangeStoreRef = await evalOnDartLibrary.safeEval(
    'WrenchStore.storeState()',
    isAlive: Disposable(),
  );

  final Instance mustangStore =
      await evalOnDartLibrary.getInstance(mustangeStoreRef, Disposable());

  final List<dynamic> storeElements = mustangStore.elements;
  final List<Map<String, dynamic>> storeData = [];

  for (var i = 0; i < storeElements?.length ?? 0; i++) {
    if (storeElements[i] != null) {
      final Instance eleRef =
          await evalOnDartLibrary.getInstance(storeElements[i], Disposable());
      final Map<String, dynamic> data = eleRef.toJson();
      String className = data['class']['name'];
      if (className.contains('\$')) {
        className = className.split('\$')[1];
      } else if (className.startsWith('_')) {
        className = className.substring(1);
      }
      final Map<String, dynamic> requiredData = {
        'className': className,
        'fields': data['fields']?.map((e) {
              final Map<String, dynamic> typeClass =
                  e['decl']['declaredType']['typeClass'];
              String value;
              if (typeClass != null) {
                final String defaultValue = e['value']['valueAsString'];
                value = primitiveDataType.contains(typeClass['name'])
                    ? defaultValue
                    : 'None primitive dataType. Click to fetch';
              }
              return {
                'name': e['decl']['name'],
                'type': typeClass != null
                    ? typeClass['name'] == 'BuiltList'
                        ? e['decl']['declaredType']['name']
                        : typeClass['name']
                    : 'unknown',
                'ref': e['value'],
                'value': value,
              };
            })?.toList() ??
            [],
      };
      storeData.add(requiredData);
      // storeData.add(data);
    }
  }

  return storeData;
}

Future<List<Map<String, dynamic>>> getObjData(
  Map<String, dynamic> instanceRefAsMap,
) async {
  if (instanceRefAsMap != null) {
    final evalOnDartLibrary = EvalOnDartLibrary(
      ['package:mustang_core/src/state/wrench_store.dart'],
      serviceManager.service,
    );

    final InstanceRef instanceRef = InstanceRef.parse(instanceRefAsMap);

    final Instance instance =
        await evalOnDartLibrary.getInstance(instanceRef, Disposable());

    final Map<String, dynamic> data = instance.toJson();
    List<Map<String, dynamic>> fields = [];

    if (data['fields'] != null) {
      for (var i = 0; i < data['fields']?.length ?? 0; i++) {
        final Map<String, dynamic> typeClass =
            data['fields'][i]['decl']['declaredType']['typeClass'];
        String value;
        if (typeClass != null) {
          final String defaultValue =
              data['fields'][i]['value']['valueAsString'];
          value = primitiveDataType.contains(typeClass['name'])
              ? defaultValue
              : 'None primitive dataType. Click to fetch';
        }
        final List<Map<String, dynamic>> listElements = [];
        if (typeClass['name'] == 'List') {
          final InstanceRef listInstanceRef =
              InstanceRef.parse(data['fields'][i]['value']);
          final Instance listInstance = await evalOnDartLibrary.getInstance(
              listInstanceRef, Disposable());
          Map<String, dynamic> listInstanceAsMap = listInstance.toJson();
          for (var j = 0; j < listInstanceAsMap['elements']?.length ?? 0; j++) {
            Map<String, dynamic> temp = listInstanceAsMap['elements'][j];
            List<Map<String, dynamic>> resp = await getObjData(temp);
            listElements.addAll(resp);
          }
          fields.addAll(listElements);
        } else {
          fields.add({
            'name': data['fields'][i]['decl']['name'],
            'type': typeClass != null ? typeClass['name'] : 'unknown',
            'ref': data['fields'][i]['value'],
            'value': value,
          });
        }
      }
    }
    String className = data['class']['name'];
    if (className.contains('\$')) {
      className = className.split('\$')[1];
    } else if (className.startsWith('_')) {
      className = className.substring(1);
    }
    final Map<String, dynamic> requiredData = {
      'className': className,
      'type': data['type'],
      'name': className,
      'ref': data,
      'fields': fields,
    };

    return [requiredData];
    // return instance.toJson();
  } else {
    return <Map<String, dynamic>>[];
  }
}

Widget _futureBuilder(
  Function(Map<String, dynamic> modelData) onPress, {
  String filterString = '',
}) {
  return FutureBuilder(
    future: getStoreData(),
    builder: (
      BuildContext context,
      AsyncSnapshot<List<Map<String, dynamic>>> storeData,
    ) {
      final List<Map<String, dynamic>> data = storeData?.data
              ?.where(
                (element) => element['className'].contains(filterString),
              )
              ?.toList() ??
          [];
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
                onTap: () => onPress(data[index]),
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
  Widget _body;
  Timer _timer;
  String _filterText = '';

  void setModelData(Map<String, dynamic> modelData) {
    setState(() {
      _modelData = modelData;
    });
  }

  void setFilterText(String inp) {
    setState(() {
      _filterText = inp;
    });
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (Timer timer) => setState(
        () {
          _body = _futureBuilder(
            setModelData,
            filterString: _filterText,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          // decoration: BoxDecoration(
          //   border: Border.all(color: Theme.of(context).dividerColor),
          // ),
          width: 400,
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context)
                                .dividerColor, //this has no effect
                          ),
                          borderRadius: BorderRadius.circular(5.0),
                        ),
                        hintText: "Search",
                      ),
                      onChanged: setFilterText,
                    ),
                  ),
                ],
              ),
              Divider(
                color: Theme.of(context).dividerColor,
              ),
              Expanded(
                child: _body == null
                    ? const Center(
                        child: Text(
                          'Loading! HEEEE-HAAYYY',
                        ),
                      )
                    : SingleChildScrollView(
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
                            children: dataViewer(context, _modelData),
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
}

List<Widget> dataViewer(BuildContext context, Map<String, dynamic> modelData) {
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
        MustangExpandedTile(field: e),
      );
    },
  );
  return modelDataWidgets;
}

class MustangExpandedTile extends StatefulWidget {
  const MustangExpandedTile({
    Key key,
    @required this.field,
  }) : super(key: key);

  final dynamic field;

  @override
  _MustangExpandedTileState createState() => _MustangExpandedTileState();
}

class _MustangExpandedTileState extends State<MustangExpandedTile> {
  Widget _body = const Center(
    child: Text('Loading...'),
  );

  void setBody() {
    setState(
      () {
        _body = FutureBuilder(
          future: getObjData(widget.field['ref']),
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
                    child: Column(
                      children: dataViewer(
                        context,
                        data[index],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: primitiveDataType.contains(widget.field['type']) == false
          ? ExpansionTile(
              title: Text(
                '${widget.field["name"]} (${widget.field["type"]})',
              ),
              children: [_body],
              onExpansionChanged: (bool status) {
                if (status) {
                  setBody();
                }
              },
            )
          : ListTile(
              title: Text(
                '${widget.field["name"]} (${widget.field["type"]})',
              ),
              subtitle: Text('${widget.field["value"]}'),
            ),
    );
  }
}
