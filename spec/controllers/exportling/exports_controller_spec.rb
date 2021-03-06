require 'spec_helper'
require 'shared/pundit_shared_contexts'

# Note: type: :controller let's rspec know this is a controller spec,
# which routes { Exportling::Engine.routes } won't work without.
describe Exportling::ExportsController, type: :controller do
  # Use Exportling's routes
  routes { Exportling::Engine.routes }

  let(:current_user) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_export_owner) { current_user }
  end

  # Create test exports (one owned by the current user)
  let!(:export) { create(:export, owner: current_user) }
  let!(:other_export) { create(:export, owner: other_user) }

  describe 'GET #index' do
    subject { get :index }

    it 'renders the :index view' do
      subject
      expect(response).to render_template(:index)
    end

    it 'assigns exports for the current user' do
      subject
      expect(assigns(:exports)).to eq([export])
    end

    describe 'authorization' do
      context 'when using pundit' do
        include_context :using_pundit

        specify 'policy_scope is called' do
          expect_any_instance_of(described_class).to receive(:policy_scope)
          subject
        end
      end

      context 'when not using pundit' do
        include_context :not_using_pundit

        specify 'policy_scope is not called' do
          expect_any_instance_of(described_class).to_not receive(:policy_scope)
          subject
        end
      end
    end
  end

  shared_examples :export_from_valid_params do
    subject { assigns(:export) }

    it 'is assigned the params' do
      expect(subject.klass).to eq p_klass
      expect(subject.params).to eq p_params
      expect(subject.file_type).to eq p_file_type
    end

    it 'is assigned to the current owner' do
      expect(subject.owner).to eq(current_user)
    end
  end

  shared_context :invalid_export_params do
    let(:p_klass) { nil }
    let(:p_file_type) { nil }
  end

  describe 'GET #new' do
    let(:params)    { { klass: p_klass, params: p_params, file_type: p_file_type } }
    let(:p_params)  { { 'foo' => 'bar' } }
    let(:request)   { get :new, params: { export: params } }

    context 'given valid params' do
      before { request }
      let(:p_klass) { 'HouseCsvExporter' }
      let(:p_file_type) { 'csv' }

      it 'renders the :new view' do
        expect(response).to render_template(:new)
      end

      describe 'new export' do
        it_behaves_like :export_from_valid_params
      end
    end

    context 'given invalid params' do
      include_context :invalid_export_params
      it 'raises an error' do
        expect { request }.to raise_error(ArgumentError)
      end
    end

    describe 'authorization' do
      let(:p_klass) { 'HouseCsvExporter' }
      let(:p_file_type) { 'csv' }

      context 'when using pundit' do
        include_context :using_pundit

        specify 'it authorizes the exporters export class' do
          expect_any_instance_of(described_class).to receive(:authorize).
            with(House, :export?)
          request
        end
      end

      context 'when not using pundit' do
        include_context :not_using_pundit

        specify 'it does not authorize the exporters export class' do
          expect_any_instance_of(described_class).to_not receive(:authorize).
            with(House, :export?)
          request
        end
      end
    end
  end

  describe 'POST #create' do
    let(:request) { post :create, params: { export: params } }

    let(:params) do
      {
        klass: p_klass,
        name: p_klass,
        params: p_params,
        file_type: p_file_type
      }
    end
    let(:p_params) { { 'foo' => 'bar' } }

    context 'given valid params' do
      before do
        # Mocking .perform allows us to spy on this class/method
        allow_any_instance_of(Exportling::Export).to receive(:perform_async!)
        request
      end

      let(:p_klass) { 'HouseCsvExporter' }
      let(:p_file_type) { 'csv' }

      it 'redirects to the :index view' do
        expect(response).to redirect_to(root_path)
      end

      it 'saves the export' do
        expect(assigns(:export)).to be_persisted
      end

      describe 'created export' do
        it_behaves_like :export_from_valid_params
      end

      it 'performs the export' do
        export = assigns(:export)
        expect(export).to have_received(:perform_async!)
      end
    end

    context 'given invalid params' do
      include_context :invalid_export_params
      it 'raises an error' do
        expect { request }.to raise_error(ArgumentError)
      end
    end

    describe 'authorization' do
      let(:p_klass) { 'HouseCsvExporter' }
      let(:p_file_type) { 'csv' }
      context 'when using pundit' do
        include_context :using_pundit
        specify 'it authorizes the exporters export class' do
          expect_any_instance_of(described_class).to receive(:authorize).
            with(House, :export?)
          request
        end
      end
      context 'when not using pundit' do
        include_context :not_using_pundit
        specify 'it does not authorize the exporters export class' do
          expect_any_instance_of(described_class).to_not receive(:authorize).
            with(House, :export?)
          request
        end
      end
    end
  end

  describe 'GET #download' do
    subject { get :download, params: { id: export.id } }
    shared_examples :download_error do
      it 'redirects to the :index view' do
        expect(response).to redirect_to(root_path)
      end

      it 'sets an error in flash' do
        expect(flash[:error]).to eq(expected_error_message)
      end
    end

    context 'when export belongs to' do
      context 'current user' do
        it 'finds the export' do
          export.perform!
          subject
          expect(assigns(:export)).to eq(export)
        end

        context 'export performed' do
          before do
            export.perform!
            subject
          end

          it 'redirects to uploaded file' do
            assigned_export = assigns(:export)
            expect(response).to redirect_to(assigned_export.output.url)
          end
        end

        context 'export not yet performed' do
          before { subject }
          let(:expected_error_message) do
            'Export cannot be downloaded until it is complete.'\
            ' Please try again later.'
          end

          it_behaves_like :download_error
        end
      end

      context 'another user' do
        let(:export) { other_export }
        before { subject }
        let(:expected_error_message) { 'Could not find export to download' }
        it_behaves_like :download_error
      end
    end

    describe 'authorization' do
      context 'when using pundit' do
        include_context :using_pundit

        specify 'that the export is authorized with pundit' do
          expect_any_instance_of(described_class).to receive(:authorize).
            with(export)
          subject
        end
      end

      context 'when not using pundit' do
        include_context :not_using_pundit

        specify 'that the export is not authorized with pundit' do
          expect_any_instance_of(described_class).to_not receive(:authorize)
          subject
        end
      end
    end
  end
end
