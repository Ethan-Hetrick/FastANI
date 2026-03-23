# Security Policy

## Supported Versions

The maintainers primarily support:

- the latest release
- the current default branch

Older branches and historical releases may not receive security fixes.

## Reporting A Vulnerability

Please do not open public issues for suspected security problems.

If GitHub private vulnerability reporting is enabled for this repository, use that workflow first. Otherwise, contact the maintainers directly and include:

- a short description of the issue
- affected version or commit
- reproduction steps or proof of concept
- any suggested mitigation, if known

We will try to acknowledge reports promptly, reproduce the issue, and coordinate a fix before public disclosure when appropriate.

## Deployment Note

FastANI is a command-line tool. If it is wrapped in a web service or workflow platform, the wrapper should treat all user inputs as untrusted and enforce:

- isolated working directories
- file path allowlists
- input size limits
- CPU, memory, and wall-time limits
- authentication, logging, and rate limiting where appropriate
