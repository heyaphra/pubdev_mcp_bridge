/// Data models for package documentation.
///
/// These models represent the complete API documentation extracted from
/// a Dart package. They support JSON serialization for caching.
library;

/// Complete documentation for a Dart package.
class PackageDoc {
  final String name;
  final String version;
  final String? description;
  final String? repository;
  final String? homepage;
  final List<LibraryDoc> libraries;

  const PackageDoc({
    required this.name,
    required this.version,
    this.description,
    this.repository,
    this.homepage,
    this.libraries = const [],
  });

  factory PackageDoc.fromJson(Map<String, dynamic> json) {
    return PackageDoc(
      name: json['name'] as String,
      version: json['version'] as String,
      description: json['description'] as String?,
      repository: json['repository'] as String?,
      homepage: json['homepage'] as String?,
      libraries:
          (json['libraries'] as List<dynamic>?)
              ?.map((e) => LibraryDoc.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'version': version,
    if (description != null) 'description': description,
    if (repository != null) 'repository': repository,
    if (homepage != null) 'homepage': homepage,
    'libraries': libraries.map((e) => e.toJson()).toList(),
  };

  /// Get all classes across all libraries.
  List<ClassDoc> get allClasses =>
      libraries.expand((lib) => lib.classes).toList();

  /// Get all functions across all libraries.
  List<FunctionDoc> get allFunctions =>
      libraries.expand((lib) => lib.functions).toList();

  /// Get all enums across all libraries.
  List<EnumDoc> get allEnums => libraries.expand((lib) => lib.enums).toList();

  @override
  String toString() => 'PackageDoc($name@$version)';
}

/// Documentation for a single library (dart file).
class LibraryDoc {
  final String name;
  final String? description;
  final List<ClassDoc> classes;
  final List<FunctionDoc> functions;
  final List<EnumDoc> enums;
  final List<TypedefDoc> typedefs;
  final List<ExtensionDoc> extensions;
  final List<MixinDoc> mixins;
  final List<VariableDoc> variables;

  const LibraryDoc({
    required this.name,
    this.description,
    this.classes = const [],
    this.functions = const [],
    this.enums = const [],
    this.typedefs = const [],
    this.extensions = const [],
    this.mixins = const [],
    this.variables = const [],
  });

  factory LibraryDoc.fromJson(Map<String, dynamic> json) {
    return LibraryDoc(
      name: json['name'] as String,
      description: json['description'] as String?,
      classes: _parseList(json['classes'], ClassDoc.fromJson),
      functions: _parseList(json['functions'], FunctionDoc.fromJson),
      enums: _parseList(json['enums'], EnumDoc.fromJson),
      typedefs: _parseList(json['typedefs'], TypedefDoc.fromJson),
      extensions: _parseList(json['extensions'], ExtensionDoc.fromJson),
      mixins: _parseList(json['mixins'], MixinDoc.fromJson),
      variables: _parseList(json['variables'], VariableDoc.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    if (classes.isNotEmpty) 'classes': classes.map((e) => e.toJson()).toList(),
    if (functions.isNotEmpty)
      'functions': functions.map((e) => e.toJson()).toList(),
    if (enums.isNotEmpty) 'enums': enums.map((e) => e.toJson()).toList(),
    if (typedefs.isNotEmpty)
      'typedefs': typedefs.map((e) => e.toJson()).toList(),
    if (extensions.isNotEmpty)
      'extensions': extensions.map((e) => e.toJson()).toList(),
    if (mixins.isNotEmpty) 'mixins': mixins.map((e) => e.toJson()).toList(),
    if (variables.isNotEmpty)
      'variables': variables.map((e) => e.toJson()).toList(),
  };
}

/// Documentation for a class.
class ClassDoc {
  final String name;
  final String? description;
  final String? superclass;
  final List<String> interfaces;
  final List<String> mixins;
  final List<String> typeParameters;
  final List<ConstructorDoc> constructors;
  final List<MethodDoc> methods;
  final List<FieldDoc> fields;
  final List<String> annotations;
  final bool isAbstract;

  const ClassDoc({
    required this.name,
    this.description,
    this.superclass,
    this.interfaces = const [],
    this.mixins = const [],
    this.typeParameters = const [],
    this.constructors = const [],
    this.methods = const [],
    this.fields = const [],
    this.annotations = const [],
    this.isAbstract = false,
  });

  factory ClassDoc.fromJson(Map<String, dynamic> json) {
    return ClassDoc(
      name: json['name'] as String,
      description: json['description'] as String?,
      superclass: json['superclass'] as String?,
      interfaces: _parseStringList(json['interfaces']),
      mixins: _parseStringList(json['mixins']),
      typeParameters: _parseStringList(json['typeParameters']),
      constructors: _parseList(json['constructors'], ConstructorDoc.fromJson),
      methods: _parseList(json['methods'], MethodDoc.fromJson),
      fields: _parseList(json['fields'], FieldDoc.fromJson),
      annotations: _parseStringList(json['annotations']),
      isAbstract: json['isAbstract'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    if (superclass != null) 'superclass': superclass,
    if (interfaces.isNotEmpty) 'interfaces': interfaces,
    if (mixins.isNotEmpty) 'mixins': mixins,
    if (typeParameters.isNotEmpty) 'typeParameters': typeParameters,
    if (constructors.isNotEmpty)
      'constructors': constructors.map((e) => e.toJson()).toList(),
    if (methods.isNotEmpty) 'methods': methods.map((e) => e.toJson()).toList(),
    if (fields.isNotEmpty) 'fields': fields.map((e) => e.toJson()).toList(),
    if (annotations.isNotEmpty) 'annotations': annotations,
    if (isAbstract) 'isAbstract': isAbstract,
  };
}

/// Documentation for a constructor.
class ConstructorDoc {
  final String name;
  final String? description;
  final List<ParameterDoc> parameters;
  final bool isConst;
  final bool isFactory;

  const ConstructorDoc({
    required this.name,
    this.description,
    this.parameters = const [],
    this.isConst = false,
    this.isFactory = false,
  });

  factory ConstructorDoc.fromJson(Map<String, dynamic> json) {
    return ConstructorDoc(
      name: json['name'] as String,
      description: json['description'] as String?,
      parameters: _parseList(json['parameters'], ParameterDoc.fromJson),
      isConst: json['isConst'] as bool? ?? false,
      isFactory: json['isFactory'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    if (parameters.isNotEmpty)
      'parameters': parameters.map((e) => e.toJson()).toList(),
    if (isConst) 'isConst': isConst,
    if (isFactory) 'isFactory': isFactory,
  };

  String get signature {
    final params = parameters.map((p) => p.signature).join(', ');
    final prefix =
        isConst
            ? 'const '
            : isFactory
            ? 'factory '
            : '';
    return '$prefix$name($params)';
  }
}

/// Documentation for a method.
class MethodDoc {
  final String name;
  final String? description;
  final String returnType;
  final List<ParameterDoc> parameters;
  final List<String> typeParameters;
  final bool isStatic;
  final bool isAbstract;
  final bool isOperator;
  final bool isGetter;
  final bool isSetter;

  const MethodDoc({
    required this.name,
    this.description,
    this.returnType = 'dynamic',
    this.parameters = const [],
    this.typeParameters = const [],
    this.isStatic = false,
    this.isAbstract = false,
    this.isOperator = false,
    this.isGetter = false,
    this.isSetter = false,
  });

  factory MethodDoc.fromJson(Map<String, dynamic> json) {
    return MethodDoc(
      name: json['name'] as String,
      description: json['description'] as String?,
      returnType: json['returnType'] as String? ?? 'dynamic',
      parameters: _parseList(json['parameters'], ParameterDoc.fromJson),
      typeParameters: _parseStringList(json['typeParameters']),
      isStatic: json['isStatic'] as bool? ?? false,
      isAbstract: json['isAbstract'] as bool? ?? false,
      isOperator: json['isOperator'] as bool? ?? false,
      isGetter: json['isGetter'] as bool? ?? false,
      isSetter: json['isSetter'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    'returnType': returnType,
    if (parameters.isNotEmpty)
      'parameters': parameters.map((e) => e.toJson()).toList(),
    if (typeParameters.isNotEmpty) 'typeParameters': typeParameters,
    if (isStatic) 'isStatic': isStatic,
    if (isAbstract) 'isAbstract': isAbstract,
    if (isOperator) 'isOperator': isOperator,
    if (isGetter) 'isGetter': isGetter,
    if (isSetter) 'isSetter': isSetter,
  };

  String get signature {
    if (isGetter) return '$returnType get $name';
    if (isSetter) {
      final param =
          parameters.isNotEmpty ? parameters.first.signature : 'value';
      return 'set $name($param)';
    }
    final typeParams =
        typeParameters.isNotEmpty ? '<${typeParameters.join(', ')}>' : '';
    final params = parameters.map((p) => p.signature).join(', ');
    final prefix = isStatic ? 'static ' : '';
    return '$prefix$returnType $name$typeParams($params)';
  }
}

/// Documentation for a field/property.
class FieldDoc {
  final String name;
  final String? description;
  final String type;
  final bool isStatic;
  final bool isFinal;
  final bool isConst;
  final bool isLate;

  const FieldDoc({
    required this.name,
    this.description,
    this.type = 'dynamic',
    this.isStatic = false,
    this.isFinal = false,
    this.isConst = false,
    this.isLate = false,
  });

  factory FieldDoc.fromJson(Map<String, dynamic> json) {
    return FieldDoc(
      name: json['name'] as String,
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'dynamic',
      isStatic: json['isStatic'] as bool? ?? false,
      isFinal: json['isFinal'] as bool? ?? false,
      isConst: json['isConst'] as bool? ?? false,
      isLate: json['isLate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    'type': type,
    if (isStatic) 'isStatic': isStatic,
    if (isFinal) 'isFinal': isFinal,
    if (isConst) 'isConst': isConst,
    if (isLate) 'isLate': isLate,
  };
}

/// Documentation for a parameter.
class ParameterDoc {
  final String name;
  final String type;
  final bool isRequired;
  final bool isNamed;
  final bool isPositional;
  final String? defaultValue;

  const ParameterDoc({
    required this.name,
    this.type = 'dynamic',
    this.isRequired = true,
    this.isNamed = false,
    this.isPositional = false,
    this.defaultValue,
  });

  factory ParameterDoc.fromJson(Map<String, dynamic> json) {
    return ParameterDoc(
      name: json['name'] as String,
      type: json['type'] as String? ?? 'dynamic',
      isRequired: json['isRequired'] as bool? ?? true,
      isNamed: json['isNamed'] as bool? ?? false,
      isPositional: json['isPositional'] as bool? ?? false,
      defaultValue: json['defaultValue'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    if (!isRequired) 'isRequired': isRequired,
    if (isNamed) 'isNamed': isNamed,
    if (isPositional) 'isPositional': isPositional,
    if (defaultValue != null) 'defaultValue': defaultValue,
  };

  String get signature {
    final req = isRequired && isNamed ? 'required ' : '';
    final def = defaultValue != null ? ' = $defaultValue' : '';
    return '$req$type $name$def';
  }
}

/// Documentation for a top-level function.
class FunctionDoc {
  final String name;
  final String? description;
  final String returnType;
  final List<ParameterDoc> parameters;
  final List<String> typeParameters;

  const FunctionDoc({
    required this.name,
    this.description,
    this.returnType = 'dynamic',
    this.parameters = const [],
    this.typeParameters = const [],
  });

  factory FunctionDoc.fromJson(Map<String, dynamic> json) {
    return FunctionDoc(
      name: json['name'] as String,
      description: json['description'] as String?,
      returnType: json['returnType'] as String? ?? 'dynamic',
      parameters: _parseList(json['parameters'], ParameterDoc.fromJson),
      typeParameters: _parseStringList(json['typeParameters']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    'returnType': returnType,
    if (parameters.isNotEmpty)
      'parameters': parameters.map((e) => e.toJson()).toList(),
    if (typeParameters.isNotEmpty) 'typeParameters': typeParameters,
  };

  String get signature {
    final typeParams =
        typeParameters.isNotEmpty ? '<${typeParameters.join(', ')}>' : '';
    final params = parameters.map((p) => p.signature).join(', ');
    return '$returnType $name$typeParams($params)';
  }
}

/// Documentation for an enum.
class EnumDoc {
  final String name;
  final String? description;
  final List<EnumValueDoc> values;
  final List<MethodDoc> methods;
  final List<FieldDoc> fields;

  const EnumDoc({
    required this.name,
    this.description,
    this.values = const [],
    this.methods = const [],
    this.fields = const [],
  });

  factory EnumDoc.fromJson(Map<String, dynamic> json) {
    return EnumDoc(
      name: json['name'] as String,
      description: json['description'] as String?,
      values: _parseList(json['values'], EnumValueDoc.fromJson),
      methods: _parseList(json['methods'], MethodDoc.fromJson),
      fields: _parseList(json['fields'], FieldDoc.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    if (values.isNotEmpty) 'values': values.map((e) => e.toJson()).toList(),
    if (methods.isNotEmpty) 'methods': methods.map((e) => e.toJson()).toList(),
    if (fields.isNotEmpty) 'fields': fields.map((e) => e.toJson()).toList(),
  };
}

/// Documentation for an enum value.
class EnumValueDoc {
  final String name;
  final String? description;

  const EnumValueDoc({required this.name, this.description});

  factory EnumValueDoc.fromJson(Map<String, dynamic> json) {
    return EnumValueDoc(
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
  };
}

/// Documentation for a typedef.
class TypedefDoc {
  final String name;
  final String? description;
  final String type;
  final List<String> typeParameters;

  const TypedefDoc({
    required this.name,
    this.description,
    this.type = 'dynamic',
    this.typeParameters = const [],
  });

  factory TypedefDoc.fromJson(Map<String, dynamic> json) {
    return TypedefDoc(
      name: json['name'] as String,
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'dynamic',
      typeParameters: _parseStringList(json['typeParameters']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    'type': type,
    if (typeParameters.isNotEmpty) 'typeParameters': typeParameters,
  };
}

/// Documentation for an extension.
class ExtensionDoc {
  final String name;
  final String? description;
  final String onType;
  final List<MethodDoc> methods;
  final List<FieldDoc> fields;

  const ExtensionDoc({
    required this.name,
    this.description,
    required this.onType,
    this.methods = const [],
    this.fields = const [],
  });

  factory ExtensionDoc.fromJson(Map<String, dynamic> json) {
    return ExtensionDoc(
      name: json['name'] as String,
      description: json['description'] as String?,
      onType: json['onType'] as String? ?? 'dynamic',
      methods: _parseList(json['methods'], MethodDoc.fromJson),
      fields: _parseList(json['fields'], FieldDoc.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    'onType': onType,
    if (methods.isNotEmpty) 'methods': methods.map((e) => e.toJson()).toList(),
    if (fields.isNotEmpty) 'fields': fields.map((e) => e.toJson()).toList(),
  };
}

/// Documentation for a mixin.
class MixinDoc {
  final String name;
  final String? description;
  final List<String> superclassConstraints;
  final List<String> interfaces;
  final List<MethodDoc> methods;
  final List<FieldDoc> fields;

  const MixinDoc({
    required this.name,
    this.description,
    this.superclassConstraints = const [],
    this.interfaces = const [],
    this.methods = const [],
    this.fields = const [],
  });

  factory MixinDoc.fromJson(Map<String, dynamic> json) {
    return MixinDoc(
      name: json['name'] as String,
      description: json['description'] as String?,
      superclassConstraints: _parseStringList(json['superclassConstraints']),
      interfaces: _parseStringList(json['interfaces']),
      methods: _parseList(json['methods'], MethodDoc.fromJson),
      fields: _parseList(json['fields'], FieldDoc.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    if (superclassConstraints.isNotEmpty)
      'superclassConstraints': superclassConstraints,
    if (interfaces.isNotEmpty) 'interfaces': interfaces,
    if (methods.isNotEmpty) 'methods': methods.map((e) => e.toJson()).toList(),
    if (fields.isNotEmpty) 'fields': fields.map((e) => e.toJson()).toList(),
  };
}

/// Documentation for a top-level variable.
class VariableDoc {
  final String name;
  final String? description;
  final String type;
  final bool isConst;
  final bool isFinal;

  const VariableDoc({
    required this.name,
    this.description,
    this.type = 'dynamic',
    this.isConst = false,
    this.isFinal = false,
  });

  factory VariableDoc.fromJson(Map<String, dynamic> json) {
    return VariableDoc(
      name: json['name'] as String,
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'dynamic',
      isConst: json['isConst'] as bool? ?? false,
      isFinal: json['isFinal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    'type': type,
    if (isConst) 'isConst': isConst,
    if (isFinal) 'isFinal': isFinal,
  };
}

// Helper functions for JSON parsing
List<T> _parseList<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) {
  if (json == null) return const [];
  return (json as List<dynamic>)
      .map((e) => fromJson(e as Map<String, dynamic>))
      .toList();
}

List<String> _parseStringList(dynamic json) {
  if (json == null) return const [];
  return (json as List<dynamic>).cast<String>();
}
