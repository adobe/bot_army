#!/usr/bin/env bash

echo 'Generating summary report...'
echo -e $(release_remote_ctl rpc 'Metrics.SummaryReport.build_report()')
