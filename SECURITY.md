# Security policy

## Reporting a vulnerability

Please don't open a public issue for security problems. Use GitHub's private reporting instead: on this repository's Security tab, choose "Report a vulnerability". I'll reply there.

If that button isn't there, open an issue that only asks for a private contact, with no details, and I'll follow up.

Useful details:

- What the problem is and which file or resource it's in
- How someone could exploit it, and what they'd get
- A suggested fix, if you have one

## Scope

This repository is the Terraform and the first-boot script that deploy an Outline server. Examples of in-scope problems:

- The security group, IAM policy or instance settings exposing more than they should
- Secrets ending up somewhere readable, such as Terraform state, user data or logs
- The bootstrap script trusting something it shouldn't

Vulnerabilities in Outline itself (the server, Manager or clients) should go to the Outline project at [OutlineFoundation/outline-server](https://github.com/OutlineFoundation/outline-server/security).

## Supported versions

Only the latest commit on `master` gets fixes.
