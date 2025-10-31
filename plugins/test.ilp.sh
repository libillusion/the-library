#!/bin/bash
# An Illusion Plugin.

declare -A ILLUSION_PLUGIN=(
  [name]="example plugin"
  [version]="0.1"
  [description]="an example license"
  [license]="Proprietary"
  [git]="None"
  [functions_prefix]="example"
  [variables_prefix]="EXAMPLE"
)

function example.worker.hooks.handle_call() {
  echo "Fuck you."
}

function example.worker.hooks.handle_response() {
  echo hi
  #example.worker.abc
}

