#!/bin/sh
# Run the geiser-kawa buttercup specs under Cask.
# Cask puts elisp/ (the package files) on the load-path; `-L .` adds the repo
# root so the specs under elisp/tests/ are discovered.
exec cask exec buttercup -L .
