Overview of production steps that can be shared across organizations
====================================================================

Some of these systems are developed by NLB. They are meant for our production environment. But we want to make it possible for other agencies to use them in their environments. Primarily members of the Nordic IT Forum.

Others are developed by other organizations.

Projects in this list should run in Docker, and have a RESTful API. Or at least have a plan to do so.


## Validation of nordic EPUBs

Contacts: [@josteinaj](https://github.com/josteinaj) / [@oscarlcarlsson](https://github.com/oscarlcarlsson)

Project: [nordic-epub3-dtbook-migrator](https://github.com/nlbdev/nordic-epub3-dtbook-migrator) - Official validator for nordic EPUBs

See also:

- [mtmse/talking-book-validator](https://github.com/mtmse/talking-book-validator) - MTMs wrapper around the validator, which runs without Pipeline 2
- [nlbdev/incoming-nordic](https://github.com/nlbdev/incoming-nordic) - NLBs wrapper around the validator for NLBs production system


## Ace: Accessibility Checker for Epub by Daisy

Project: [daisy/ace](https://github.com/daisy/ace) - Official repository

See also:

- [daisy/ace#373](https://github.com/daisy/ace/pull/373) - PR to be able to run the official version of Ace as a microservice
- [nlbdev/daisy-ace](https://github.com/nlbdev/daisy-ace) - NLBs wrapper for running Ace as a microservice


## Epubcheck: EPUB validator

Project: [https://github.com/w3c/epubcheck](https://github.com/w3c/epubcheck)

See also:

- [w3c/epubcheck#1127](https://github.com/w3c/epubcheck/pull/1127) - PR to be able to build a Docker image, but still missing a REST API


## Talking book checker

Project: [mtmse/talking-book-checker](https://github.com/mtmse/talking-book-checker) - MTMs project for finding non-technical errors in narrated books


## Running XSLTs

Project: [service-saxon](https://github.com/nlbdev/service-saxon) - A microservice to run XSLTs
