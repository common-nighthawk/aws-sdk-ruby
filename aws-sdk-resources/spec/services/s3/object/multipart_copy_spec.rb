require 'spec_helper'

module Aws
  module S3
    describe Object do

      let(:object) { S3::Object.new('bucket', 'unescaped/key path', stub_responses: true) }

      let(:client) { object.client }

      describe 'default behavior' do
        describe '#copy_from' do

          it 'supports the deprecated form' do
            expect(client).to receive(:copy_object).with({
              bucket: 'bucket',
              key: 'unescaped/key path',
              copy_source: 'source-bucket/escaped/source/key%20path',
            })
            object.copy_from(copy_source: 'source-bucket/escaped/source/key%20path')
          end

          it 'accepts a string source' do
            expect(client).to receive(:copy_object).with({
              bucket: 'bucket',
              key: 'unescaped/key path',
              copy_source: 'source-bucket/source/key%20path',
            })
            object.copy_from('source-bucket/source/key path')
          end

          it 'accepts a hash source' do
            expect(client).to receive(:copy_object).with({
              bucket: 'bucket',
              key: 'unescaped/key path',
              copy_source: 'source-bucket/unescaped/source/key%20path'
            })
            object.copy_from(bucket:'source-bucket', key:'unescaped/source/key path')
          end

          it 'accept a hash with options merged' do
            expect(client).to receive(:copy_object).with({
              bucket: 'bucket',
              key: 'unescaped/key path',
              copy_source: 'source-bucket/source-key',
              content_type: 'text/plain',
            })
            object.copy_from(
              bucket: 'source-bucket',
              key: 'source-key',
              content_type: 'text/plain'
            )
          end

          it 'accepts an S3::Object source' do
            expect(client).to receive(:copy_object).with({
              bucket: 'bucket',
              key: 'unescaped/key path',
              copy_source: 'source-bucket/unescaped/source/key%20path',
            })
            src = S3::Object.new('source-bucket', 'unescaped/source/key path', stub_responses:true)
            object.copy_from(src)
          end

          it 'accepts additional options' do
            expect(client).to receive(:copy_object).with({
              bucket: 'bucket',
              key: 'unescaped/key path',
              copy_source: 'source-bucket/source-key',
              acl: 'public-read',
            })
            object.copy_from('source-bucket/source-key', acl: 'public-read')
          end

          it 'raises an error on an invalid source' do
            expect {
              object.copy_from(:source)
            }.to raise_error(ArgumentError)
          end

        end

        describe '#copy_to' do

          it 'accepts a string source' do
            expect(client).to receive(:copy_object).with({
              bucket: 'target-bucket',
              key: 'target-key',
              copy_source: 'bucket/unescaped/key%20path',
            })
            object.copy_to('target-bucket/target-key')
          end

          it 'accepts a hash source' do
            expect(client).to receive(:copy_object).with({
              bucket: 'target-bucket',
              key: 'target-key',
              copy_source: 'bucket/unescaped/key%20path',
            })
            object.copy_to(bucket:'target-bucket', key:'target-key')
          end

          it 'accept a hash with options merged' do
            expect(client).to receive(:copy_object).with({
              bucket: 'target-bucket',
              key: 'target-key',
              copy_source: 'bucket/unescaped/key%20path',
              content_type: 'text/plain',
            })
            object.copy_to(
              bucket: 'target-bucket',
              key: 'target-key',
              content_type: 'text/plain'
            )
          end

          it 'accepts an S3::Object source' do
            expect(client).to receive(:copy_object).with({
              bucket: 'target-bucket',
              key: 'target-key',
              copy_source: 'bucket/unescaped/key%20path',
            })
            target = S3::Object.new('target-bucket', 'target-key', stub_responses:true)
            object.copy_to(target)
          end

          it 'accepts additional options' do
            expect(client).to receive(:copy_object).with({
              bucket: 'target-bucket',
              key: 'target-key',
              copy_source: 'bucket/unescaped/key%20path',
              acl: 'public-read',
            })
            object.copy_to('target-bucket/target-key', acl: 'public-read')
          end

          it 'raises an error on an invalid targets' do
            expect {
              object.copy_to(:target)
            }.to raise_error(ArgumentError)
          end

        end
      end

      describe 'multipart_copy: true' do
        describe '#copy_from' do

          before(:each) do
            size = 300 * 1024 * 1024 # 300MB
            allow(client).to receive(:head_object).with(
              bucket: 'source-bucket',
              key: 'source/key'
            ).and_return(client.stub_data(:head_object, content_length: size))
          end

          it 'performs multipart uploads when :multipart_copy is true' do
            expect(client).to receive(:create_multipart_upload).
              with(bucket: 'bucket', key: 'unescaped/key path').
              and_return(client.stub_data(:create_multipart_upload, upload_id:'id'))
            (1..6).each do |n|
              expect(client).to receive(:upload_part_copy).with(
                bucket: 'bucket',
                key: 'unescaped/key path',
                part_number: n,
                copy_source: 'source-bucket/source/key',
                copy_source_range: "bytes=#{(n-1)*52428800}-#{n*52428800-1}",
                upload_id: 'id'
              ).and_return(client.stub_data(:upload_part_copy, copy_part_result:{etag: "etag#{n}"}))
            end
            expect(client).to receive(:complete_multipart_upload).with({
              bucket: 'bucket',
              key: 'unescaped/key path',
              upload_id: 'id',
              multipart_upload: {
                parts: (1..6).map { |n| { etag: "etag#{n}", part_number: n } }
              }
            })
            object.copy_from('source-bucket/source/key', multipart_copy: true)
          end

          it 'supports alternative part sizes' do

            expect(client).to receive(:create_multipart_upload).
              with(bucket: 'bucket', key: 'unescaped/key path').
              and_return(client.stub_data(:create_multipart_upload, upload_id:'id'))

            (1..60).each do |n|
              expect(client).to receive(:upload_part_copy).with(
                bucket: 'bucket',
                key: 'unescaped/key path',
                part_number: n,
                copy_source: 'source-bucket/source/key',
                copy_source_range: "bytes=#{(n-1)*5242880}-#{n*5242880-1}",
                upload_id: 'id'
              ).and_return(client.stub_data(:upload_part_copy, copy_part_result:{etag: "etag#{n}"}))
            end
            expect(client).to receive(:complete_multipart_upload).with({
              bucket: 'bucket',
              key: 'unescaped/key path',
              upload_id: 'id',
              multipart_upload: {
                parts: (1..60).map { |n| { etag: "etag#{n}", part_number: n } }
              }
            })
            object.copy_from('source-bucket/source/key',
              multipart_copy: true,
              min_part_size: 5 * 1024 * 1024
            )
          end

          it 'aborts the upload on errors' do
            client.stub_responses(:upload_part_copy, 'NoSuchKey')
            allow(client).to receive(:create_multipart_upload).
              with(bucket: 'bucket', key: 'unescaped/key path').
              and_return(client.stub_data(:create_multipart_upload, upload_id:'id'))
            expect(client).to receive(:abort_multipart_upload).
              with(bucket: 'bucket', key: 'unescaped/key path', upload_id: 'id')
            expect {
              object.copy_from('source-bucket/source/key', multipart_copy: true)
            }.to raise_error(Aws::S3::Errors::NoSuchKey)
          end

          it 'rejects files smaller than 5MB' do
            size = 4 * 1024 * 1024
            allow(client).to receive(:head_object).with(
              bucket: 'source-bucket',
              key: 'source/key'
            ).and_return(client.stub_data(:head_object, content_length: size))
            expect {
              object.copy_from('source-bucket/source/key', multipart_copy: true)
            }.to raise_error(ArgumentError, /smaller than 5MB/)
          end

          it 'accepts file size option to avoid HEAD request' do
            expect(client).not_to receive(:head_object)
            object.copy_from('source-bucket/source/key',
              multipart_copy: true,
              content_length: 10 * 1024 * 1024
            )
          end

          it 'does not modify given options' do
            options = { multipart_copy: true }
            object.copy_from('source-bucket/source/key', options)
            expect(options).to eq(multipart_copy: true)
          end

        end
      end
    end
  end
end
