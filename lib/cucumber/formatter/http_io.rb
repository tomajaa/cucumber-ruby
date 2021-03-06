require 'net/http'

module Cucumber
  module Formatter
    class HTTPIO
      class << self
        # Returns an IO that will write to a HTTP request's body
        def open(url, https_verify_mode = nil)
          @https_verify_mode = https_verify_mode
          uri, method, headers = build_uri_method_headers(url)

          @req = build_request(uri, method, headers)
          @http = build_client(uri, https_verify_mode)

          read_io, write_io = IO.pipe
          @req.body_stream = read_io

          class << write_io
            attr_writer :request_thread

            def start_request(http, req)
              @req_thread = Thread.new do
                begin
                  res = http.request(req)
                  raise StandardError, "request to #{req.uri} failed with status #{res.code}" if res.code.to_i >= 400
                rescue StandardError => e
                  @http_error = e
                end
              end
            end

            def close
              super
              begin
                @req_thread.join
              rescue StandardError
                nil
              end
              raise @http_error unless @http_error.nil?
            end
          end
          write_io.start_request(@http, @req)

          write_io
        end

        def build_uri_method_headers(url)
          uri = URI(url)
          query_pairs = uri.query ? URI.decode_www_form(uri.query) : []

          # Build headers from query parameters prefixed with http- and extract HTTP method
          http_query_pairs = query_pairs.select { |pair| pair[0] =~ /^http-/ }
          http_query_hash_without_prefix = Hash[http_query_pairs.map do |pair|
                                                  [
                                                    pair[0][5..-1].downcase, # remove http- prefix
                                                    pair[1]
                                                  ]
                                                end]
          method = http_query_hash_without_prefix.delete('method') || 'POST'
          headers = {
            'transfer-encoding' => 'chunked'
          }.merge(http_query_hash_without_prefix)

          # Update the query with the http-* parameters removed
          remaining_query_pairs = query_pairs - http_query_pairs
          new_query_hash = Hash[remaining_query_pairs]
          uri.query = URI.encode_www_form(new_query_hash) unless new_query_hash.empty?
          [uri, method, headers]
        end

        private

        def build_request(uri, method, headers)
          method_class_name = "#{method[0].upcase}#{method[1..-1].downcase}"
          req = Net::HTTP.const_get(method_class_name).new(uri)
          headers.each do |header, value|
            req[header] = value
          end
          req
        end

        def build_client(uri, https_verify_mode)
          http = Net::HTTP.new(uri.hostname, uri.port)
          if uri.scheme == 'https'
            http.use_ssl = true
            http.verify_mode = https_verify_mode if https_verify_mode
          end
          http
        end
      end
    end
  end
end
