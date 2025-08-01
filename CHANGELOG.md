# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New Client ID service for unique device identification in CRDT operations
- Support for configurable authentication backends (OIDC/solid-auth)
- Dedicated Solid profile parser for improved RDF handling

### Fixed
- Authentication backend selection now works correctly based on configuration
- Improved OIDC token handling and DPoP authentication flow
- Enhanced error handling in authentication operations

### Improved
- Modular service registration with configurable factory methods
- Better separation of concerns in authentication architecture
- More comprehensive integration testing coverage
