# frozen_string_literal: true
require 'test/unit'

# Test for --jit option
class TestJIT < Test::Unit::TestCase
  JIT_TIMEOUT = 600 # 10min for each...
  JIT_SUCCESS_PREFIX = 'JIT success \(\d+\.\dms\)'
  SUPPORTED_COMPILERS = [
    'gcc',
    'clang',
  ]

  def test_jit
    skip unless jit_supported?

    assert_eval_with_jit('print proc { 1 + 1 }.call', stdout: '2', success_count: 1)
  end

  def test_jit_output
    skip unless jit_supported?

    out, err = eval_with_jit('5.times { puts "MJIT" }', verbose: 1, min_calls: 5)
    assert_equal("MJIT\n" * 5, out)
    assert_match(/^#{JIT_SUCCESS_PREFIX}: block in <main>@-e:1 -> .+_ruby_mjit_p\d+u\d+\.c$/, err)
    assert_match(/^Successful MJIT finish$/, err)
  end

  private

  # Shorthand for normal test cases
  def assert_eval_with_jit(script, stdout: nil, success_count:)
    out, err = eval_with_jit(script, verbose: 1, min_calls: 1)
    if jit_supported?
      actual = err.scan(/^#{JIT_SUCCESS_PREFIX}:/).size
      assert_equal(
        success_count, actual,
        "Expected #{success_count} times of JIT success, but succeeded #{actual} times.\n\n"\
        "script:\n#{code_block(script)}\nstderr:\n#{code_block(err)}",
      )
    end
    if stdout
      assert_match(stdout, out, "Expected stdout #{out.inspect} to match #{stdout.inspect} with script:\n#{code_block(script)}")
    end
  end

  # Run Ruby script with --jit-wait (Synchronous JIT compilation).
  # Returns [stdout, stderr]
  def eval_with_jit(script, verbose: 0, min_calls: 5, timeout: JIT_TIMEOUT)
    stdout, stderr, status = EnvUtil.invoke_ruby(
      ['--disable-gems', '--jit-wait', "--jit-verbose=#{verbose}", "--jit-min-calls=#{min_calls}", '-e', script],
      '', true, true, timeout: timeout,
    )
    assert_equal(true, status.success?, "Failed to run script with JIT:\n#{code_block(script)}\nstdout:\n#{code_block(stdout)}\nstderr:\n#{code_block(stderr)}")
    [stdout, stderr]
  end

  def code_block(code)
    "```\n#{code}\n```\n\n"
  end

  def jit_supported?
    return @jit_supported if defined?(@jit_supported)

    # Experimental. If you want to ensure JIT is working with this test, please set this for now.
    if ENV.key?('RUBY_FORCE_TEST_JIT')
      return @jit_supported = true
    end

    # Very pessimistic check. With this check, we can't ensure JIT is working.
    begin
      _, err = eval_with_jit('proc {}.call', verbose: 1, min_calls: 1, timeout: 10)
      @jit_supported = err.match?(JIT_SUCCESS_PREFIX)
    rescue Timeout::Error
      $stderr.puts "TestJIT: #jit_supported? check timed out"
      @jit_supported = false
    end
  end
end
