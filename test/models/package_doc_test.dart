/// Tests for package documentation models and JSON serialization.
///
/// Covers [PackageDoc], [LibraryDoc], [ClassDoc], and all related model classes
/// including serialization, deserialization, round-trip validation, and helper
/// methods like [allClasses], [allFunctions], and [allEnums].
///
/// Test isolation: Uses in-memory test data and fixture files from
/// test/fixtures/ for integration scenarios.
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:pubdev_mcp_bridge/src/models/package_doc.dart';

void main() {
  group('PackageDoc', () {
    test('creates instance with required fields', () {
      final doc = PackageDoc(name: 'test_package', version: '1.0.0');

      expect(doc.name, equals('test_package'));
      expect(doc.version, equals('1.0.0'));
      expect(doc.description, isNull);
      expect(doc.repository, isNull);
      expect(doc.homepage, isNull);
      expect(doc.libraries, isEmpty);
    });

    test('creates instance with all fields', () {
      final library = LibraryDoc(name: 'test_lib');
      final doc = PackageDoc(
        name: 'test_package',
        version: '1.0.0',
        description: 'Test description',
        repository: 'https://github.com/test/repo',
        homepage: 'https://test.dev',
        libraries: [library],
      );

      expect(doc.name, equals('test_package'));
      expect(doc.version, equals('1.0.0'));
      expect(doc.description, equals('Test description'));
      expect(doc.repository, equals('https://github.com/test/repo'));
      expect(doc.homepage, equals('https://test.dev'));
      expect(doc.libraries, hasLength(1));
    });

    test('serializes to JSON correctly', () {
      final doc = PackageDoc(
        name: 'test_package',
        version: '1.0.0',
        description: 'Test description',
        libraries: [],
      );

      final json = doc.toJson();

      expect(json['name'], equals('test_package'));
      expect(json['version'], equals('1.0.0'));
      expect(json['description'], equals('Test description'));
      expect(json['libraries'], isEmpty);
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'name': 'test_package',
        'version': '1.0.0',
        'description': 'Test description',
        'repository': 'https://github.com/test/repo',
        'homepage': 'https://test.dev',
        'libraries': [],
      };

      final doc = PackageDoc.fromJson(json);

      expect(doc.name, equals('test_package'));
      expect(doc.version, equals('1.0.0'));
      expect(doc.description, equals('Test description'));
      expect(doc.repository, equals('https://github.com/test/repo'));
      expect(doc.homepage, equals('https://test.dev'));
      expect(doc.libraries, isEmpty);
    });

    test('round-trip JSON serialization', () {
      final original = PackageDoc(
        name: 'test_package',
        version: '1.0.0',
        description: 'Test description',
        repository: 'https://github.com/test/repo',
        homepage: 'https://test.dev',
        libraries: [LibraryDoc(name: 'lib1'), LibraryDoc(name: 'lib2')],
      );

      final json = original.toJson();
      final restored = PackageDoc.fromJson(json);

      expect(restored.name, equals(original.name));
      expect(restored.version, equals(original.version));
      expect(restored.description, equals(original.description));
      expect(restored.repository, equals(original.repository));
      expect(restored.homepage, equals(original.homepage));
      expect(restored.libraries.length, equals(original.libraries.length));
    });

    test('loads complete fixture from file', () async {
      final fixtureFile = File('test/fixtures/sample_package_doc.json');
      final jsonString = await fixtureFile.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      final doc = PackageDoc.fromJson(json);

      expect(doc.name, equals('test_package'));
      expect(doc.version, equals('1.0.0'));
      expect(doc.libraries, hasLength(1));
      expect(doc.libraries.first.classes, hasLength(1));
      expect(doc.libraries.first.functions, hasLength(1));
      expect(doc.libraries.first.enums, hasLength(1));
    });

    test('allClasses returns classes from all libraries', () {
      final doc = PackageDoc(
        name: 'test',
        version: '1.0.0',
        libraries: [
          LibraryDoc(
            name: 'lib1',
            classes: [ClassDoc(name: 'Class1'), ClassDoc(name: 'Class2')],
          ),
          LibraryDoc(name: 'lib2', classes: [ClassDoc(name: 'Class3')]),
        ],
      );

      final allClasses = doc.allClasses;

      expect(allClasses, hasLength(3));
      expect(
        allClasses.map((c) => c.name),
        containsAll(['Class1', 'Class2', 'Class3']),
      );
    });

    test('allFunctions returns functions from all libraries', () {
      final doc = PackageDoc(
        name: 'test',
        version: '1.0.0',
        libraries: [
          LibraryDoc(name: 'lib1', functions: [FunctionDoc(name: 'func1')]),
          LibraryDoc(
            name: 'lib2',
            functions: [FunctionDoc(name: 'func2'), FunctionDoc(name: 'func3')],
          ),
        ],
      );

      final allFunctions = doc.allFunctions;

      expect(allFunctions, hasLength(3));
      expect(
        allFunctions.map((f) => f.name),
        containsAll(['func1', 'func2', 'func3']),
      );
    });

    test('allEnums returns enums from all libraries', () {
      final doc = PackageDoc(
        name: 'test',
        version: '1.0.0',
        libraries: [
          LibraryDoc(name: 'lib1', enums: [EnumDoc(name: 'Enum1')]),
          LibraryDoc(name: 'lib2', enums: [EnumDoc(name: 'Enum2')]),
        ],
      );

      final allEnums = doc.allEnums;

      expect(allEnums, hasLength(2));
      expect(allEnums.map((e) => e.name), containsAll(['Enum1', 'Enum2']));
    });

    test('toString returns readable representation', () {
      final doc = PackageDoc(name: 'test_pkg', version: '2.0.0');
      expect(doc.toString(), equals('PackageDoc(test_pkg@2.0.0)'));
    });
  });

  group('LibraryDoc', () {
    test('creates instance with required fields', () {
      final lib = LibraryDoc(name: 'test_library');

      expect(lib.name, equals('test_library'));
      expect(lib.description, isNull);
      expect(lib.classes, isEmpty);
      expect(lib.functions, isEmpty);
      expect(lib.enums, isEmpty);
    });

    test('serializes to JSON with only populated fields', () {
      final lib = LibraryDoc(
        name: 'test_lib',
        description: 'Test library',
        classes: [ClassDoc(name: 'TestClass')],
      );

      final json = lib.toJson();

      expect(json['name'], equals('test_lib'));
      expect(json['description'], equals('Test library'));
      expect(json['classes'], hasLength(1));
      expect(json['functions'], isNull); // Empty lists not included
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'name': 'test_lib',
        'description': 'Test library',
        'classes': [
          {'name': 'Class1'},
        ],
        'functions': [
          {'name': 'func1', 'returnType': 'void'},
        ],
      };

      final lib = LibraryDoc.fromJson(json);

      expect(lib.name, equals('test_lib'));
      expect(lib.classes, hasLength(1));
      expect(lib.functions, hasLength(1));
    });
  });

  group('ClassDoc', () {
    test('creates instance with required fields', () {
      final cls = ClassDoc(name: 'Calculator');

      expect(cls.name, equals('Calculator'));
      expect(cls.isAbstract, isFalse);
      expect(cls.constructors, isEmpty);
      expect(cls.methods, isEmpty);
      expect(cls.fields, isEmpty);
    });

    test('creates abstract class', () {
      final cls = ClassDoc(name: 'BaseClass', isAbstract: true);
      expect(cls.isAbstract, isTrue);
    });

    test('serializes inheritance info', () {
      final cls = ClassDoc(
        name: 'MyClass',
        superclass: 'BaseClass',
        interfaces: ['Interface1', 'Interface2'],
        mixins: ['Mixin1'],
      );

      final json = cls.toJson();

      expect(json['superclass'], equals('BaseClass'));
      expect(json['interfaces'], equals(['Interface1', 'Interface2']));
      expect(json['mixins'], equals(['Mixin1']));
    });

    test('deserializes from JSON with all members', () {
      final json = {
        'name': 'TestClass',
        'description': 'A test class',
        'superclass': 'Object',
        'isAbstract': true,
        'constructors': [
          {'name': 'TestClass', 'parameters': []},
        ],
        'methods': [
          {'name': 'testMethod', 'returnType': 'void', 'parameters': []},
        ],
        'fields': [
          {'name': 'testField', 'type': 'String'},
        ],
      };

      final cls = ClassDoc.fromJson(json);

      expect(cls.name, equals('TestClass'));
      expect(cls.description, equals('A test class'));
      expect(cls.isAbstract, isTrue);
      expect(cls.constructors, hasLength(1));
      expect(cls.methods, hasLength(1));
      expect(cls.fields, hasLength(1));
    });
  });

  group('MethodDoc', () {
    test('creates instance with required fields', () {
      final method = MethodDoc(name: 'calculate');

      expect(method.name, equals('calculate'));
      expect(method.returnType, equals('dynamic'));
      expect(method.isStatic, isFalse);
      expect(method.isAbstract, isFalse);
    });

    test('creates static method', () {
      final method = MethodDoc(name: 'fromJson', isStatic: true);
      expect(method.isStatic, isTrue);
    });

    test('creates getter', () {
      final method = MethodDoc(
        name: 'value',
        returnType: 'int',
        isGetter: true,
      );

      expect(method.isGetter, isTrue);
      expect(method.signature, equals('int get value'));
    });

    test('creates setter', () {
      final method = MethodDoc(
        name: 'value',
        isSetter: true,
        parameters: [ParameterDoc(name: 'newValue', type: 'int')],
      );

      expect(method.isSetter, isTrue);
      expect(method.signature, contains('set value'));
    });

    test('signature includes type parameters', () {
      final method = MethodDoc(
        name: 'map',
        returnType: 'List<R>',
        typeParameters: ['T', 'R'],
        parameters: [ParameterDoc(name: 'mapper', type: 'R Function(T)')],
      );

      final sig = method.signature;

      expect(sig, contains('<T, R>'));
      expect(sig, contains('List<R>'));
      expect(sig, contains('map'));
    });

    test('signature for static method', () {
      final method = MethodDoc(
        name: 'create',
        returnType: 'MyClass',
        isStatic: true,
      );

      expect(method.signature, startsWith('static'));
    });
  });

  group('FieldDoc', () {
    test('creates instance with required fields', () {
      final field = FieldDoc(name: 'count');

      expect(field.name, equals('count'));
      expect(field.type, equals('dynamic'));
      expect(field.isStatic, isFalse);
      expect(field.isFinal, isFalse);
      expect(field.isConst, isFalse);
    });

    test('creates final field', () {
      final field = FieldDoc(name: 'id', type: 'String', isFinal: true);

      expect(field.isFinal, isTrue);
      expect(field.type, equals('String'));
    });

    test('creates const field', () {
      final field = FieldDoc(name: 'maxValue', type: 'int', isConst: true);
      expect(field.isConst, isTrue);
    });

    test('creates static field', () {
      final field = FieldDoc(name: 'instance', isStatic: true);
      expect(field.isStatic, isTrue);
    });

    test('serializes all flags', () {
      final field = FieldDoc(
        name: 'value',
        type: 'String',
        isStatic: true,
        isFinal: true,
        isLate: true,
      );

      final json = field.toJson();

      expect(json['isStatic'], isTrue);
      expect(json['isFinal'], isTrue);
      expect(json['isLate'], isTrue);
      expect(json['isConst'], isNull); // Not included when false
    });
  });

  group('ParameterDoc', () {
    test('creates required positional parameter', () {
      final param = ParameterDoc(name: 'value', type: 'int');

      expect(param.name, equals('value'));
      expect(param.type, equals('int'));
      expect(param.isRequired, isTrue);
      expect(param.isNamed, isFalse);
    });

    test('creates optional named parameter', () {
      final param = ParameterDoc(
        name: 'timeout',
        type: 'Duration',
        isRequired: false,
        isNamed: true,
      );

      expect(param.isNamed, isTrue);
      expect(param.isRequired, isFalse);
    });

    test('creates required named parameter', () {
      final param = ParameterDoc(
        name: 'id',
        type: 'String',
        isRequired: true,
        isNamed: true,
      );

      expect(param.signature, startsWith('required'));
    });

    test('signature includes default value', () {
      final param = ParameterDoc(
        name: 'count',
        type: 'int',
        isRequired: false,
        defaultValue: '0',
      );

      expect(param.signature, equals('int count = 0'));
    });

    test('signature for required named parameter', () {
      final param = ParameterDoc(
        name: 'name',
        type: 'String',
        isRequired: true,
        isNamed: true,
      );

      expect(param.signature, equals('required String name'));
    });
  });

  group('FunctionDoc', () {
    test('creates instance with required fields', () {
      final func = FunctionDoc(name: 'greet');

      expect(func.name, equals('greet'));
      expect(func.returnType, equals('dynamic'));
      expect(func.parameters, isEmpty);
      expect(func.typeParameters, isEmpty);
    });

    test('signature with parameters', () {
      final func = FunctionDoc(
        name: 'add',
        returnType: 'int',
        parameters: [
          ParameterDoc(name: 'a', type: 'int'),
          ParameterDoc(name: 'b', type: 'int'),
        ],
      );

      expect(func.signature, equals('int add(int a, int b)'));
    });

    test('signature with type parameters', () {
      final func = FunctionDoc(
        name: 'identity',
        returnType: 'T',
        typeParameters: ['T'],
        parameters: [ParameterDoc(name: 'value', type: 'T')],
      );

      expect(func.signature, contains('<T>'));
      expect(func.signature, contains('identity'));
    });

    test('serializes and deserializes correctly', () {
      final original = FunctionDoc(
        name: 'process',
        returnType: 'Future<void>',
        parameters: [ParameterDoc(name: 'data', type: 'String')],
      );

      final json = original.toJson();
      final restored = FunctionDoc.fromJson(json);

      expect(restored.name, equals(original.name));
      expect(restored.returnType, equals(original.returnType));
      expect(restored.parameters.length, equals(original.parameters.length));
    });
  });

  group('EnumDoc', () {
    test('creates instance with required fields', () {
      final enumDoc = EnumDoc(name: 'Status');

      expect(enumDoc.name, equals('Status'));
      expect(enumDoc.values, isEmpty);
      expect(enumDoc.methods, isEmpty);
    });

    test('creates enum with values', () {
      final enumDoc = EnumDoc(
        name: 'Color',
        values: [
          EnumValueDoc(name: 'red', description: 'Red color'),
          EnumValueDoc(name: 'green'),
          EnumValueDoc(name: 'blue'),
        ],
      );

      expect(enumDoc.values, hasLength(3));
      expect(enumDoc.values.first.name, equals('red'));
      expect(enumDoc.values.first.description, equals('Red color'));
    });

    test('serializes enum with methods and fields', () {
      final enumDoc = EnumDoc(
        name: 'Priority',
        values: [EnumValueDoc(name: 'high'), EnumValueDoc(name: 'low')],
        methods: [MethodDoc(name: 'toString', returnType: 'String')],
        fields: [FieldDoc(name: 'value', type: 'int')],
      );

      final json = enumDoc.toJson();

      expect(json['name'], equals('Priority'));
      expect(json['values'], hasLength(2));
      expect(json['methods'], hasLength(1));
      expect(json['fields'], hasLength(1));
    });
  });

  group('ConstructorDoc', () {
    test('creates default constructor', () {
      final ctor = ConstructorDoc(name: '');

      expect(ctor.name, equals(''));
      expect(ctor.isConst, isFalse);
      expect(ctor.isFactory, isFalse);
    });

    test('creates named constructor', () {
      final ctor = ConstructorDoc(name: 'fromJson');
      expect(ctor.name, equals('fromJson'));
    });

    test('creates const constructor', () {
      final ctor = ConstructorDoc(name: '', isConst: true);
      expect(ctor.isConst, isTrue);
      expect(ctor.signature, startsWith('const'));
    });

    test('creates factory constructor', () {
      final ctor = ConstructorDoc(name: 'create', isFactory: true);
      expect(ctor.isFactory, isTrue);
      expect(ctor.signature, startsWith('factory'));
    });

    test('signature with parameters', () {
      final ctor = ConstructorDoc(
        name: 'Person',
        parameters: [
          ParameterDoc(name: 'name', type: 'String'),
          ParameterDoc(name: 'age', type: 'int'),
        ],
      );

      expect(ctor.signature, equals('Person(String name, int age)'));
    });
  });

  group('TypedefDoc', () {
    test('creates instance with required fields', () {
      final typedef = TypedefDoc(name: 'Callback');

      expect(typedef.name, equals('Callback'));
      expect(typedef.type, equals('dynamic'));
    });

    test('creates function typedef', () {
      final typedef = TypedefDoc(
        name: 'IntCallback',
        type: 'void Function(int)',
      );

      expect(typedef.type, equals('void Function(int)'));
    });

    test('serializes with type parameters', () {
      final typedef = TypedefDoc(
        name: 'Mapper',
        type: 'R Function(T)',
        typeParameters: ['T', 'R'],
      );

      final json = typedef.toJson();

      expect(json['typeParameters'], equals(['T', 'R']));
    });
  });

  group('ExtensionDoc', () {
    test('creates instance with required fields', () {
      final ext = ExtensionDoc(name: 'StringExtensions', onType: 'String');

      expect(ext.name, equals('StringExtensions'));
      expect(ext.onType, equals('String'));
      expect(ext.methods, isEmpty);
    });

    test('serializes extension with methods', () {
      final ext = ExtensionDoc(
        name: 'IntExtensions',
        onType: 'int',
        methods: [
          MethodDoc(name: 'isEven', returnType: 'bool', isGetter: true),
        ],
      );

      final json = ext.toJson();

      expect(json['onType'], equals('int'));
      expect(json['methods'], hasLength(1));
    });

    test('deserializes from JSON', () {
      final json = {
        'name': 'ListExtensions',
        'onType': 'List<T>',
        'methods': [
          {'name': 'firstOrNull', 'returnType': 'T?', 'parameters': []},
        ],
      };

      final ext = ExtensionDoc.fromJson(json);

      expect(ext.name, equals('ListExtensions'));
      expect(ext.onType, equals('List<T>'));
      expect(ext.methods, hasLength(1));
    });
  });

  group('MixinDoc', () {
    test('creates instance with required fields', () {
      final mixin = MixinDoc(name: 'Loggable');

      expect(mixin.name, equals('Loggable'));
      expect(mixin.superclassConstraints, isEmpty);
      expect(mixin.methods, isEmpty);
    });

    test('serializes with constraints', () {
      final mixin = MixinDoc(
        name: 'Comparable',
        superclassConstraints: ['Object'],
        interfaces: ['Equatable'],
      );

      final json = mixin.toJson();

      expect(json['superclassConstraints'], equals(['Object']));
      expect(json['interfaces'], equals(['Equatable']));
    });
  });

  group('VariableDoc', () {
    test('creates instance with required fields', () {
      final variable = VariableDoc(name: 'version');

      expect(variable.name, equals('version'));
      expect(variable.type, equals('dynamic'));
      expect(variable.isConst, isFalse);
      expect(variable.isFinal, isFalse);
    });

    test('creates const variable', () {
      final variable = VariableDoc(
        name: 'maxLength',
        type: 'int',
        isConst: true,
      );

      expect(variable.isConst, isTrue);
    });

    test('creates final variable', () {
      final variable = VariableDoc(
        name: 'instance',
        type: 'MyClass',
        isFinal: true,
      );

      expect(variable.isFinal, isTrue);
    });

    test('round-trip serialization', () {
      final original = VariableDoc(
        name: 'config',
        type: 'Map<String, dynamic>',
        isFinal: true,
      );

      final json = original.toJson();
      final restored = VariableDoc.fromJson(json);

      expect(restored.name, equals(original.name));
      expect(restored.type, equals(original.type));
      expect(restored.isFinal, equals(original.isFinal));
    });
  });

  group('Integration - Full PackageDoc from fixture', () {
    test('can parse and serialize complete fixture', () async {
      final fixtureFile = File('test/fixtures/sample_package_doc.json');
      final jsonString = await fixtureFile.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      final doc = PackageDoc.fromJson(json);

      // Verify structure
      expect(doc.name, equals('test_package'));
      expect(doc.libraries.first.name, equals('test_package'));

      // Verify class
      final calculator = doc.allClasses.first;
      expect(calculator.name, equals('Calculator'));
      expect(calculator.constructors, hasLength(1));
      expect(calculator.methods, hasLength(1));
      expect(calculator.fields, hasLength(1));

      // Verify method
      final addMethod = calculator.methods.first;
      expect(addMethod.name, equals('add'));
      expect(addMethod.parameters, hasLength(2));
      expect(addMethod.returnType, equals('int'));

      // Verify function
      final greet = doc.allFunctions.first;
      expect(greet.name, equals('greet'));
      expect(greet.returnType, equals('String'));

      // Verify enum
      final status = doc.allEnums.first;
      expect(status.name, equals('Status'));
      expect(status.values, hasLength(2));

      // Round-trip
      final serialized = doc.toJson();
      final deserialized = PackageDoc.fromJson(serialized);
      expect(deserialized.name, equals(doc.name));
      expect(deserialized.libraries.length, equals(doc.libraries.length));
    });
  });
}
