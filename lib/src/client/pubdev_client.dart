/// HTTP client for interacting with pub.dev API.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Exception thrown when a package is not found on pub.dev.
class PackageNotFoundException implements Exception {
  final String packageName;
  PackageNotFoundException(this.packageName);

  @override
  String toString() => 'Package not found: $packageName';
}

/// Exception thrown when pub.dev API request fails.
class PubdevClientException implements Exception {
  final String message;
  final int? statusCode;
  PubdevClientException(this.message, [this.statusCode]);

  @override
  String toString() => statusCode != null
      ? 'PubdevClientException: $message ($statusCode)'
      : message;
}

/// Client for pub.dev HTTP API.
class PubdevClient {
  static const _baseUrl = 'https://pub.dev/api';
  static const _archiveUrl = 'https://pub.dev/packages';

  final http.Client _client;

  /// Creates a new pub.dev client.
  PubdevClient([http.Client? client]) : _client = client ?? http.Client();

  /// Closes the HTTP client.
  void close() => _client.close();

  /// Fetches package metadata from pub.dev.
  Future<Map<String, dynamic>> getPackageMetadata(String packageName) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/packages/$packageName'),
    );

    if (response.statusCode == 404) {
      throw PackageNotFoundException(packageName);
    }

    if (response.statusCode != 200) {
      throw PubdevClientException(
        'Failed to fetch package metadata',
        response.statusCode,
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Gets the latest version of a package.
  Future<String> getLatestVersion(String packageName) async {
    final metadata = await getPackageMetadata(packageName);
    return metadata['latest']['version'] as String;
  }

  /// Resolves a version string (or 'latest') to an actual version.
  Future<String> resolveVersion(String packageName, String? version) async {
    if (version == null || version == 'latest') {
      return getLatestVersion(packageName);
    }
    // Verify the version exists
    final metadata = await getPackageMetadata(packageName);
    final versions = (metadata['versions'] as List<dynamic>)
        .map((v) => v['version'] as String)
        .toList();
    if (!versions.contains(version)) {
      throw PubdevClientException(
          'Version $version not found for $packageName');
    }
    return version;
  }

  /// Downloads a package archive (.tar.gz) to the specified path.
  Future<void> downloadArchive(
    String packageName,
    String version,
    String outputPath,
  ) async {
    final url = '$_archiveUrl/$packageName/versions/$version.tar.gz';
    final response = await _client.get(Uri.parse(url));

    if (response.statusCode == 404) {
      throw PackageNotFoundException('$packageName@$version');
    }

    if (response.statusCode != 200) {
      throw PubdevClientException(
        'Failed to download archive',
        response.statusCode,
      );
    }

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(response.bodyBytes);
  }
}
