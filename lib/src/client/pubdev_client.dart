/// HTTP client for interacting with the pub.dev API.
///
/// Provides methods for fetching package metadata and downloading package
/// archives from pub.dev. Handles version resolution and error conditions.
///
/// ## Usage
///
/// ```dart
/// final client = PubdevClient();
///
/// // Get latest version
/// final version = await client.getLatestVersion('dio');
/// print('Latest: $version');
///
/// // Download package
/// await client.downloadArchive('dio', version, 'dio.tar.gz');
///
/// client.close();
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Exception thrown when a package is not found on pub.dev.
///
/// This is thrown when attempting to fetch metadata or download a package
/// that doesn't exist on pub.dev, or when a specific version doesn't exist.
class PackageNotFoundException implements Exception {
  /// The package name that was not found.
  final String packageName;

  /// Creates a package not found exception for [packageName].
  PackageNotFoundException(this.packageName);

  @override
  String toString() => 'Package not found: $packageName';
}

/// Exception thrown when pub.dev API request fails.
///
/// This covers HTTP errors, network issues, and other API failures
/// that aren't specifically a 404 (which uses [PackageNotFoundException]).
class PubdevClientException implements Exception {
  /// The error message.
  final String message;

  /// The HTTP status code if available.
  final int? statusCode;

  /// Creates a pub.dev client exception with [message] and optional [statusCode].
  PubdevClientException(this.message, [this.statusCode]);

  @override
  String toString() => statusCode != null
      ? 'PubdevClientException: $message ($statusCode)'
      : message;
}

/// HTTP client for interacting with pub.dev REST API.
///
/// Provides methods to:
/// - Fetch package metadata from pub.dev
/// - Resolve package versions
/// - Download package archives
///
/// All methods handle HTTP errors appropriately, throwing either
/// [PackageNotFoundException] for 404s or [PubdevClientException] for other errors.
///
/// Example:
/// ```dart
/// final client = PubdevClient();
/// try {
///   final metadata = await client.getPackageMetadata('dio');
///   print('Description: ${metadata['latest']['pubspec']['description']}');
/// } finally {
///   client.close();
/// }
/// ```
class PubdevClient {
  static const _baseUrl = 'https://pub.dev/api';
  static const _archiveUrl = 'https://pub.dev/packages';

  final http.Client _client;

  /// Creates a new pub.dev client.
  ///
  /// Optionally provide a custom HTTP [client] for testing or
  /// to reuse an existing client instance.
  PubdevClient([http.Client? client]) : _client = client ?? http.Client();

  /// Closes the underlying HTTP client.
  ///
  /// Call this when done with the client to free resources.
  /// After calling [close], no further requests can be made.
  void close() => _client.close();

  /// Fetches complete package metadata from pub.dev for [packageName].
  ///
  /// Returns the raw JSON metadata including package info, all versions,
  /// and the latest version details.
  ///
  /// Throws [PackageNotFoundException] if the package doesn't exist.
  /// Throws [PubdevClientException] on other HTTP errors.
  ///
  /// Example:
  /// ```dart
  /// final metadata = await client.getPackageMetadata('dio');
  /// print('Latest: ${metadata['latest']['version']}');
  /// ```
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

  /// Gets the latest published version number for [packageName].
  ///
  /// Returns the version string (e.g., "5.4.0").
  ///
  /// Throws [PackageNotFoundException] if the package doesn't exist.
  /// Throws [PubdevClientException] on other HTTP errors.
  ///
  /// Example:
  /// ```dart
  /// final latest = await client.getLatestVersion('dio');
  /// print('Latest dio version: $latest');
  /// ```
  Future<String> getLatestVersion(String packageName) async {
    final metadata = await getPackageMetadata(packageName);
    return metadata['latest']['version'] as String;
  }

  /// Resolves a version string to an actual version number.
  ///
  /// If [version] is `null` or `'latest'`, returns the latest version.
  /// Otherwise, verifies that [version] exists for [packageName].
  ///
  /// Throws [PackageNotFoundException] if the package or version doesn't exist.
  /// Throws [PubdevClientException] on other HTTP errors.
  ///
  /// Example:
  /// ```dart
  /// final v1 = await client.resolveVersion('dio', null);      // latest
  /// final v2 = await client.resolveVersion('dio', 'latest');  // latest
  /// final v3 = await client.resolveVersion('dio', '5.4.0');   // verified 5.4.0
  /// ```
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

  /// Downloads a package archive to [outputPath].
  ///
  /// Downloads the .tar.gz archive for [packageName] at [version] from pub.dev
  /// and saves it to [outputPath]. Creates parent directories if needed.
  ///
  /// Throws [PackageNotFoundException] if the package/version doesn't exist.
  /// Throws [PubdevClientException] on other HTTP errors.
  ///
  /// Example:
  /// ```dart
  /// await client.downloadArchive('dio', '5.4.0', '/tmp/dio-5.4.0.tar.gz');
  /// print('Downloaded dio@5.4.0');
  /// ```
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
