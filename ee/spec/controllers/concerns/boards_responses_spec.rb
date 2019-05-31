# frozen_string_literal: true

require 'spec_helper'

describe BoardsResponses do
  let(:controller_class) do
    Class.new do
      include BoardsResponses
    end
  end

  subject(:controller) { controller_class.new }

  before do
    stub_licensed_features(scoped_issue_board: true)
    stub_licensed_features(multiple_project_issue_boards: true)
  end

  describe '#serialize_as_json' do
    let!(:board) { create(:board, milestone: milestone) }
    context 'with milestone' do
      let(:milestone) { create(:milestone) }

      before do
        board.update_attribute(:milestone_id, milestone.id)
      end

      it 'serialises properly' do
        expected = { id: board.id, name: board.name, milestone: { id: milestone.id, title: milestone.title } }

        expect(subject.serialize_as_json(board)).to match(expected)
      end
    end

    context 'without milestone' do
      let(:milestone) { nil }
      it 'serialises properly' do
        expected = { id: board.id, name: board.name }

        expect(subject.serialize_as_json(board)).to eq(expected)
      end
    end
  end
end
