require 'cucumber/formatter/backtrace_filter'

module Cucumber
  module Formatter
    describe BacktraceFilter do
      context '#exception' do
        before do
          trace = %w[a b
                     _anything__/vendor/rails__anything_
                     _anything__lib/cucumber__anything_
                     _anything__bin/cucumber:__anything_
                     _anything__lib/rspec__anything_
                     _anything__gems/__anything_
                     _anything__minitest__anything_
                     _anything__test/unit__anything_
                     _anything__Xgem/ruby__anything_
                     _anything__lib/ruby/__anything_
                     _anything__.rbenv/versions/2.3/bin/bundle__anything_]
          @exception = Exception.new
          @exception.set_backtrace(trace)
        end

        it 'filters unnecessary traces' do
          BacktraceFilter.new(@exception).exception
          expect(@exception.backtrace).to eql %w[a b]
        end

        context 'when configured through environment variable' do
          let(:backtrace_filters) do
            %w[
              /vendor/rails
              lib/cucumber
              bin/cucumber:
              lib/rspec
              minitest
              test/unit
              .gem/ruby
              lib/ruby/
              bin/bundle
            ]
          end

          before do
            stub_const(
              'Cucumber::Formatter::BACKTRACE_FILTER_PATTERNS',
              Regexp.new(backtrace_filters.join('|'))
            )
          end

          it 'filters configured traces only' do
            BacktraceFilter.new(@exception).exception
            expect(@exception.backtrace).to eql %w[a b _anything__gems/__anything_]
          end
        end
      end
    end
  end
end
