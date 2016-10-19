# -*- coding: utf-8 -*-
import os
from os.path import join, getsize
import json
import unicodedata
import re
import sys


def strip_and_count(line, level=0):
    if line.startswith("    "):
        level += 1
        return strip_and_count(line[4:], level)
    else:
        return line, level


def slugify(value):
    """
    Converts to lowercase, removes non-word characters (alphanumerics and
    underscores) and converts spaces to hyphens. Also strips leading and
    trailing whitespace.
    """
    value = re.sub('[^\w\s-]', '', value).strip().lower()
    return re.sub('[-\s]+', '-', value)


def access_item(dictionnary, stack):
    if len(stack) == 1:
        return dictionnary.setdefault(stack[0], {})
    elif len(stack) > 1:
        return access_item(dictionnary[stack.pop(0)], stack)
    else:
        return dictionnary



def parse_sysbench_result(path): # noqa
    lines = open(path)
    out = {}

    out['test-cmd'] = re.match(r'# (.*)', lines.next()).group(1)
    test_params = re.match(r'# (.*)', lines.next()).group(1).split(" ")
    out['test-params'] = " ".join(test_params[1:])
    out['test-name'] = slugify("-".join(test_params))
    sys_bench_version = re.match(r'(sysbench .*):', lines.next()).group(1)
    out['version'] = sys_bench_version

    last_level = 0
    last_key = None
    stack = []
    for line in lines:
        parsed_line = re.match(r'Doing (.*)', line)
        if parsed_line:
            out["test"] = slugify(parsed_line.group(1))
            continue
        line, level = strip_and_count(line)

        # Trying to get rw information
        parsed_line = re.match(
            r'Read (\S+)  Written (\S+)  Total transferred (\S+)  \((.*)\)',
            line
        )
        if parsed_line:
            out['transfered'] = {
                'read': parsed_line.group(1),
                'written': parsed_line.group(2),
                'total': parsed_line.group(3),
                'bandwidth': parsed_line.group(4),
            }
            continue

        parsed_line = re.match(r'(.*):(\s+(.*))?$', line)
        if parsed_line is None:
            continue
        key = slugify(parsed_line.group(1))

        if level > last_level:
            stack.append(last_key)
        if level < last_level:
            for i in range(level, last_level):
                stack.pop()
        current_pos = access_item(out, stack[:])
        try:
            value = parsed_line.group(3)
            if value == '':
                current_pos[key] = {}
            else:
                # Value may have additional option
                parsed_value = re.match(r'(\S+)(\s+\(([^)]+)\)?)', value)
                if parsed_value:
                    current_pos[key] = parsed_value.group(1)
                    current_pos[key+"-extra-data"] = parsed_value.group(3)
                else:
                    current_pos[key] = value
        except:
            pass

        last_level = level
        last_key = key

    # Post

    if out['test'] in ("random-write-test", "random-read-test"):
        parsed_ops = re.match(r'(\d+) Read, (\d+) Write, (\d+) Other',
                              out['operations-performed'])
        out['operations-performed'] = {
            'read': int(parsed_ops.group(1)),
            'write': int(parsed_ops.group(2)),
            'other': int(parsed_ops.group(3)),
        }
    return out


benchmark_results = {}

for root, dirs, files in os.walk(sys.argv[1]):
    for name in files:
        bench_res = parse_sysbench_result(join(root, name))
        benchmark_results[bench_res['test-name']] = bench_res

print json.dumps(benchmark_results, sort_keys=True,
                 indent=4, separators=(',', ': '))
