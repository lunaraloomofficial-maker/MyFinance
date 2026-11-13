#!/usr/bin/env python3
"""Run the same core assertions without XCTest when only Command Line Tools exist."""
import pathlib, re, subprocess
root = pathlib.Path(__file__).resolve().parent.parent
build = root / '.build' / 'standalone'
build.mkdir(parents=True, exist_ok=True)
tests = (root / 'MyFinanceTests/Core/FinanceTests.swift').read_text()
tests = tests.replace('import XCTest', 'import Foundation').replace('@testable import MyFinanceCore', '')
tests = tests.replace('XCTAssertEqual(try ', 'try XCTAssertEqual(try ')
shim = '''
var checks = 0
var failures = 0
class XCTestCase {}
func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) rethrows { checks += 1; if try a() != b() { failures += 1; print("FAIL \\(file):\\(line) \\(message)") } }
func XCTAssertTrue(_ a: @autoclosure () throws -> Bool, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) rethrows { checks += 1; if try !a() { failures += 1; print("FAIL \\(file):\\(line) \\(message)") } }
func XCTAssertFalse(_ a: @autoclosure () throws -> Bool, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) rethrows { checks += 1; if try a() { failures += 1; print("FAIL \\(file):\\(line) \\(message)") } }
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) { checks += 1; do { _ = try expression(); failures += 1; print("FAIL expected error \\(file):\\(line)") } catch {} }
'''
calls = []
for name, body in re.findall(r'final class (\w+): XCTestCase \{(.*?)(?=\nfinal class|\Z)', tests, re.S):
    for method in re.findall(r'func (test\w+)\(\)(?: throws)?', body):
        calls.append(f'do {{ try {name}().{method}(); print("PASS {name}.{method}") }} catch {{ failures += 1; print("FAIL {name}.{method}: \\(error)") }}')
main = '\n'.join(calls) + '\nprint("\\(checks) assertions, \\(failures) failures")\nif failures > 0 { exit(1) }\n'
(build / 'main.swift').write_text(shim + tests + '\n' + main)
files = sorted((root / 'MyFinance/Core/Finance').glob('*.swift'))
subprocess.run(['swiftc', '-O', '-suppress-warnings', '-module-cache-path', str(build / 'cache'), *map(str, files), str(build / 'main.swift'), '-o', str(build / 'core-tests')], check=True)
subprocess.run([str(build / 'core-tests')], check=True)
