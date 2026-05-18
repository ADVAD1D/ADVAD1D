### ADVAD Security and Architecture 

### Report: Encryption of Compiled Godot Games and Executables,

## Introduction

This document outlines the security architecture implemented for protecting game assets, scripts, and resources in exported Godot executables in ADVAD. The primary mechanism relies on PCK file encryption using AES-256, combined with custom-compiled export templates. This approach provides a practical layer of protection against casual asset extraction while acknowledging the inherent limitations of client-side security.

## Encryption Architecture

Core Mechanism
Godot packs all project resources (scenes, scripts, textures, audio, etc.) into a .pck file (or embeds it directly into the executable). When encryption is enabled:

The PCK file is encrypted using AES-256 in CBC mode.
The encryption key (256-bit) is compiled directly into the custom export template binary.
At runtime, the Godot engine decrypts the resources on-the-fly using the embedded key.

## Key Components

Custom Export Templates: Official precompiled templates do not support encryption. Custom templates must be built from source with the encryption key defined at compile time.
Export Preset Configuration: In the Godot editor, the "Encrypt Exported PCK" option is enabled and the matching key is provided.
Binary Integration: The key resides in the final executable, protected by compilation optimizations (stripping symbols, release builds).

## Security Benefits

Prevents easy extraction of assets using common tools (e.g., simple PCK viewers or unpackers).,
Protects GDScript source code, scene structures, and resource files from casual inspection or "script kiddie" ripping.,
Maintains full game functionality with minimal performance overhead during loading.

## Implementation Details

Key Generation: Use a strong, randomly generated 256-bit key (e.g., via secure tools supporting AES-256-CBC).
Template Compilation: Build export templates from Godot source code, passing the encryption key during the build process.

## Limitations and Threat Model

Important Note: This encryption is not unbreakable. Since the decryption key must be available at runtime within the executable:

Determined reverse engineers can locate the key in the binary (especially with debugging tools or memory analysis).
It serves primarily as a deterrent rather than absolute protection.
Assets remain vulnerable to sophisticated attacks (binary patching, memory dumping, etc.).

## Conclusion,

The PCK encryption system in Godot provides an effective balance between usability and security for most indie and small-studio projects. While it does not offer military-grade protection (impossible in fully offline client executables), it successfully deters casual and moderate threats, protecting advad intellectual property during distribution. Although I provide access to the source code, it's best to avoid reverse engineering to prevent exposing sensitive access tokens.

For questions regarding the implementation or further enhancements, refer to the project’s development documentation.

### Data Collection Notice

ADVAD uses anonymous device identifiers (UIDs) temporarily to maintain the security of transmissions and the integrity of global scores. No personally identifiable information is collected.

This data is stored on the backend infrastructure hosted on Render and is not sold to any third party.

### Vulnerability reporting
We take security breaches or flaws in the scoring system or AI API consumption very seriously.

If you find a severe vulnerability (such as the ability to bypass token authentication, encryption vulnerabilities, or injections affecting server integrity), please do not open a public issue.

Instead, report it directly by sending an email to: angelleonardohern3@gmail.com

Please provide clear details on how to reproduce the vulnerability. We will evaluate and fix the issue as soon as possible.