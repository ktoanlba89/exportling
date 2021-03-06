require 'spec_helper'

describe Exportling::ExportDecorator do
  let(:exporter_class)    { HouseCsvExporter }
  let(:export)            { create(:export, klass: exporter_class.to_s, status: 'foo') }
  let(:decorated_export)  { export.decorate }

  describe 'invalid_attributes_message' do
    subject { decorated_export.invalid_attributes_message }

    context 'export valid' do
      specify { expect(subject).to eq '' }
    end

    context 'export invalid' do
      before do
        export.klass     = nil
        export.file_type = nil
      end
      let(:expected_message) do
        'Please ensure the export form supplies all required attributes.'\
        " Klass can't be blank. File type can't be blank."
      end

      specify { expect(subject).to eq(expected_message) }
    end
  end

  describe 'elapsed time' do
    before do
      export.started_at = Time.zone.now
      export.completed_at = 1.hour.from_now
    end
  end
end
