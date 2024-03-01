#!/usr/bin/env bash
sh -c $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sed -e 's.#!/bin/sh.#!/usr/bin/env sh.')
