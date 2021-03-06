require 'spec_helper'

describe Exportling::Exporter::ClassInstanceVariables do
  describe 'delegations' do
    subject { Exportling::Exporter.new }
    it { should delegate(:fields).to(:class) }
    it { should delegate(:field_names).to(:class) }
    it { should delegate(:query_class_name).to(:class) }
    it { should delegate(:associations).to(:class) }
  end

  describe 'class methods' do
    describe '.fields' do
      context 'no fields have been set' do
        specify { expect(Exportling::Exporter.fields).to be_empty }
      end

      context 'fields have been set in the extending class' do
        specify { expect(HouseCsvExporter.fields).to match_array [:id, :price, :square_meters] }
      end
    end

    describe '.field_names' do
      context 'no fields have been set' do
        specify { expect(Exportling::Exporter.field_names).to be_empty }
      end

      context 'fields have been set in the extending class' do
        it 'returns the field names as strings' do
          expect(HouseCsvExporter.field_names).to match_array ['id', 'price', 'square_meters']
        end
      end
    end

    describe '.query_class' do
      context 'not set' do
        specify { expect(Exportling::Exporter.query_class_name).to be_nil }
      end

      context 'set in extending class' do
        specify { expect(HouseCsvExporter.query_class_name).to eq 'HouseExporterQuery' }
      end
    end

    describe '.associations' do
      context 'not set' do
        specify { expect(Exportling::Exporter.associations).to be_empty }
      end

      context 'set' do
        subject { HouseCsvExporter.associations }
        specify { expect(subject).to be_a(Hash) }
        specify { expect(subject[:rooms]).to be_a(Exportling::Exporter::AssociationDetails) }
      end
    end
  end
end
