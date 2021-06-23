import 'dart:async';

import 'package:devtools_app/src/common_widgets.dart';
import 'package:devtools_app/src/eval_on_dart_library.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/inspector/inspector_service.dart';
import 'package:devtools_app/src/screen.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';
import 'package:flutter_json_widget/flutter_json_widget.dart';

const List<String> primitiveDataType = ['bool', 'int', 'double', 'String'];

class MustangStoreScreen extends Screen {
  const MustangStoreScreen()
      : super.conditional(
          id: id,
          requiresLibrary: 'package:mustang_core',
          title: 'Mustang Store',
          icon: Icons.run_circle,
        );

  static const id = 'mustang-store';

  // only 1 reference to inspector in the entire tab
  EvalOnDartLibrary get _widgetInspectorEval {
    return EvalOnDartLibrary(
      inspectorLibraryUriCandidates,
      serviceManager.service,
    );
  }

  // only 1 reference to mustang store in the entire tab
  EvalOnDartLibrary get _mustangEval {
    return EvalOnDartLibrary(
      ['package:mustang_core/src/state/wrench_store.dart'],
      serviceManager.service,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreScreen(
      mustangEval: _mustangEval,
      widgetInspectorEval: _widgetInspectorEval,
    );
  }
}

class StoreScreen extends StatefulWidget {
  const StoreScreen({
    Key key,
    @required this.mustangEval,
    @required this.widgetInspectorEval,
  }) : super(key: key);

  final EvalOnDartLibrary mustangEval;
  final EvalOnDartLibrary widgetInspectorEval;

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
      const Duration(seconds: 2), // polling data every 2 seconds from the store
      (Timer timer) => setState(
        () {
          _body = modelListBuilder(
            setModelData,
            selectedModelData: _modelData,
            filterString: _filterText,
            mustandEval: widget.mustangEval,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
    widget.mustangEval.dispose();
    widget.widgetInspectorEval.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
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
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(5.0),
                        ),
                        hintText: 'Search',
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
                    ? Center(
                        child: Text(
                          'Loading! HEEEE-HAAYYY',
                          style: Theme.of(context).textTheme.headline5,
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
                            children: dataViewer(
                              context,
                              _modelData,
                              widget.widgetInspectorEval,
                              widget.mustangEval,
                            ),
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

List<Widget> dataViewer(BuildContext context, Map<String, dynamic> modelData,
    EvalOnDartLibrary widgetInspectorEval, EvalOnDartLibrary mustangEval) {
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
        MustangExpandedTile(
          field: e,
          widgetInspectorEval: widgetInspectorEval,
          mustangEval: mustangEval,
        ),
      );
    },
  );
  return modelDataWidgets;
}

class MustangExpandedTile extends StatefulWidget {
  const MustangExpandedTile({
    Key key,
    @required this.field,
    @required this.mustangEval,
    @required this.widgetInspectorEval,
  }) : super(key: key);

  final dynamic field;
  final EvalOnDartLibrary mustangEval;
  final EvalOnDartLibrary widgetInspectorEval;

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
        _body = objBuilder(
          widget.field['ref'],
          widget.mustangEval,
          widget.widgetInspectorEval,
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

// required to prevent garbage collection resulting in sentinel error
Future<InstanceRef> tagToPersist(
  InstanceRef instanceRef,
  EvalOnDartLibrary widgetInspectorEval, {
  dispose = false,
}) async {
  final InstanceRef ref = await widgetInspectorEval.safeEval(
    'WidgetInspectorService.instance.toId(instanceRef, "heehaww")',
    isAlive: Disposable(),
    scope: {'instanceRef': instanceRef.id},
  );
  return ref;
}

// used to poll data from the store
Future<List<Map<String, dynamic>>> getStoreData(
  EvalOnDartLibrary mustangEval,
) async {
  final InstanceRef mustangeStoreRef = await mustangEval.safeEval(
    'WrenchStore.storeState()',
    isAlive: Disposable(),
  );

  final Instance mustangStore =
      await mustangEval.getInstance(mustangeStoreRef, Disposable());

  final List<dynamic> storeElements = mustangStore.elements;
  final List<Map<String, dynamic>> storeData = [];

  for (var i = 0; i < storeElements?.length ?? 0; i++) {
    if (storeElements[i] != null) {
      final Instance eleRef =
          await mustangEval.getInstance(storeElements[i], Disposable());
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
      // storeDat.add(data);
    }
  }
  return storeData;
}

// to poll data for a non-primitive datatype using InstanceRef
Future<List<Map<String, dynamic>>> getObjData(
  Map<String, dynamic> instanceRefAsMap,
  EvalOnDartLibrary mustandEval,
  EvalOnDartLibrary widgetInspectorEval,
) async {
  if (instanceRefAsMap != null) {
    final InstanceRef instanceRef = InstanceRef.parse(instanceRefAsMap);

    // mark object to make sure its not garbage collected
    final InstanceRef persistentRef = await tagToPersist(
      instanceRef,
      widgetInspectorEval,
    );

    // get the object using the ref
    final InstanceRef persistentInstanceRef =
        await widgetInspectorEval.safeEval(
      'WidgetInspectorService.instance.toObject(instanceRef, "heehaww")',
      isAlive: Disposable(),
      scope: {'instanceRef': persistentRef.id},
    );

    final Instance instance = await mustandEval.getInstance(
      persistentInstanceRef,
      Disposable(),
    );

    final Map<String, dynamic> data = instance.toJson();
    final List<Map<String, dynamic>> fields = [];

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
          final Instance listInstance =
              await mustandEval.getInstance(listInstanceRef, Disposable());
          final Map<String, dynamic> listInstanceAsMap = listInstance.toJson();
          for (var j = 0; j < listInstanceAsMap['elements']?.length ?? 0; j++) {
            final Map<String, dynamic> temp = listInstanceAsMap['elements'][j];
            final List<Map<String, dynamic>> resp = await getObjData(
              temp,
              mustandEval,
              widgetInspectorEval,
            );
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

// build a widget for an non-primitive datatype
Widget objBuilder(
  Map<String, dynamic> instanceRefAsMap,
  EvalOnDartLibrary mustangEval,
  EvalOnDartLibrary widgetInspectorEval,
) {
  return FutureBuilder(
    future: getObjData(instanceRefAsMap, mustangEval, widgetInspectorEval),
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
                  widgetInspectorEval,
                  mustangEval,
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// build list of models to be shown in left panel
Widget modelListBuilder(
  Function(Map<String, dynamic> modelData) onPress, {
  Map<String, dynamic> selectedModelData,
  String filterString = '',
  EvalOnDartLibrary mustandEval,
}) {
  return FutureBuilder(
    future: getStoreData(mustandEval),
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
          final String className = data[index]['className'];
          if (selectedModelData != null &&
              className == selectedModelData['className']) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onPress(data[index]);
            });
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
