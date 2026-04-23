#!/bin/bash

set -e

echo ">>> Fixing ownership for frappe user..."
sudo chown frappe:frappe -R /workspace/frappe-bench
