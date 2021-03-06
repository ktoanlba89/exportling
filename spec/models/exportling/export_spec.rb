require 'spec_helper'

describe Exportling::Export do
  # This exporter is defined in the dummy app
  let(:exporter_class)  { HouseCsvExporter }
  let(:export)          { create(:export, klass: exporter_class.to_s, status: 'foo') }

  describe '#worker_class' do
    subject { export.worker_class }
    specify { expect(subject).to eq exporter_class }
  end

  describe '#authorize_on_class' do
    subject { export.authorize_on_class }

    let(:worker_class) { double('Worker Class') }

    before do
      allow(export).to receive(:worker_class) { worker_class }
      allow(worker_class).to receive(:authorize_on_class_name) { class_name }
    end

    context 'when class name provided' do
      let(:class_name) { 'House' }

      specify { expect(subject).to eq(House) }
    end

    context 'when class name omitted' do
      let(:class_name) { nil }

      specify { expect(subject).to be_nil }
    end
  end

  describe '#completed?' do
    subject { export.completed? }
    before  { export.update_attributes(status: status) }
    context 'status is not "completed"' do
      let(:status) { 'created' }
      it { should eq false }
    end

    context 'status is "completed"' do
      let(:status) { 'completed' }
      it { should eq true }
    end
  end

  describe '#incomplete?' do
    before  { allow(export).to receive(:completed?) { completed } }
    subject { export.incomplete? }
    context 'when complete' do
      let(:completed) { true }
      specify { expect(subject).to eq false }
    end

    context 'when incomplete' do
      let(:completed) { false }
      specify { expect(subject).to eq true }
    end
  end

  describe '#processing?' do
    before  { export.status = export_status }
    subject { export.processing? }

    context 'when status is processing' do
      let(:export_status) { 'processing' }
      specify { expect(subject).to eq true }
    end

    context 'when status is not processing' do
      let(:export_status) { 'created' }
      specify { expect(subject).to eq false }
    end
  end

  describe 'file_name' do
    let(:created_time)        { Time.zone.parse('Feb 1, 2009') }
    let(:export_id)           { export.id }

    before  { export.update_column(:created_at, created_time) }

    context "given an export_file_name_suffix is set" do
      before  { Exportling.export_file_name_suffix = "[DLM=Sensitive]" }
      specify { expect(export.file_name).to eq "#{export_id}_houses_2009-02-01[DLM=Sensitive].csv" }
    end

    context "given no export_file_name_suffix is set" do
      before  { Exportling.export_file_name_suffix = nil }
      specify { expect(export.file_name).to eq "#{export_id}_houses_2009-02-01.csv" }
    end
  end

  describe 'status changes' do
    subject { export.status }
    describe '#complete!' do
      before  { export.complete! }
      specify { expect(subject).to eq 'completed' }
    end

    describe '#fail!' do
      before  { export.fail! }
      specify { expect(subject).to eq 'failed' }
    end

    describe 'set_processing!' do
      before  { export.set_processing! }
      specify { expect(subject).to eq 'processing' }
    end

    describe '#perform!' do
      subject { export.perform! }
      it 'calls perform! on the worker class' do
        expect(export.worker_class).to receive(:perform).with(export.id)
        subject
      end
    end

    describe '#perform_async!' do
      Sidekiq::Testing.fake!
      subject { export.perform_async! }

      it 'queues its exporter for processing' do
        expect { subject }.to change(export.worker_class.jobs, :size).by(1)
      end
    end
  end

  describe 'Uploader' do
    let(:temp_export_file)      { Tempfile.new('test_export_file') }
    let(:temp_export_filename)  { File.basename(temp_export_file) }
    let(:expected_file_path)    { "exports/#{export.owner_id}/#{temp_export_filename}" }

   describe '#output' do
      subject { export.output }
      context 'when no file added' do
        specify { expect(subject).to be_a(Exportling::ExportUploader) }
        specify { expect(subject.path).to be_nil }
        it 'does not create the file' do
          expect(export.output.file).to be_nil
        end
      end

      context 'when file added' do
        before do
          export.output = temp_export_file
          export.save!
        end

        specify do
          expect(subject).to be_a(Exportling::ExportUploader)
          expect(subject.path).to include(expected_file_path)
        end

        it 'creates the file' do
          expect(export.output.file.exists?).to be_truthy
        end
      end
    end
  end
end
