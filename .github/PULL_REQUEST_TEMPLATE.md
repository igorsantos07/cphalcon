<!--
  Make sure you're following the points below so your PR get's correctly reviewed. After reading,
  remove the template and use this space to describe your changes.
-->

Pull Request Checklist
======================

- Don't submit your pull requests to the "master" branch. Branch from the required branch and,
  if needed, rebase to the proper branch before submitting your pull request. If it doesn't
  merge cleanly with master you may be asked to rebase your changes.
- Don't put submodule updates in your pull request unless they are to landed commits.
- Add tests relevant to the fixed bug or new feature. See our testing guide for more information.
- Phalcon 2 is written in Zephir, please do not submit commits that modify C generated files
  directly or those whose functionality/fixes are implemented in the C programming language
- Remove any change to ext/kernel / *.zep.c / *.zep.h files before submitting the pull request
