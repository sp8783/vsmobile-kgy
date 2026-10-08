ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

# ローテーションのテストデータ。pairings は [[team1_p1, team1_p2], [team2_p1, team2_p2]] をプレイヤー名で並べたもの
module RotationTestHelper
  PAIRINGS = [
    [ %w[A B], %w[C D] ],
    [ %w[A E], %w[B C] ],
    [ %w[D E], %w[A C] ],
    [ %w[B D], %w[C E] ],
    [ %w[A D], %w[B E] ],
    [ %w[C E], %w[A B] ],
    [ %w[B C], %w[D E] ],
    [ %w[A C], %w[D B] ]
  ].freeze

  def build_players(names = %w[A B C D E])
    names.index_with do |name|
      User.create!(username: "player_#{name.downcase}", nickname: "#{name}さん", password: "password123")
    end
  end

  def build_rotation(players, pairings: PAIRINGS)
    event = Event.create!(name: "テスト対戦会", held_on: Date.new(2026, 10, 11))
    rotation = event.rotations.create!(round_number: 1, is_active: true, current_match_index: 0)
    pairings.each_with_index do |(team1, team2), index|
      rotation.rotation_matches.create!(
        match_index: index,
        team1_player1: players.fetch(team1[0]), team1_player2: players.fetch(team1[1]),
        team2_player1: players.fetch(team2[0]), team2_player2: players.fetch(team2[1]),
        started_at: index.zero? ? Time.current : nil
      )
    end
    rotation
  end

  def suit_ids
    suit = MobileSuit.first || MobileSuit.create!(name: "テスト機体", series: "テスト", cost: 3000)
    { team1_player1: suit.id, team1_player2: suit.id, team2_player1: suit.id, team2_player2: suit.id }
  end

  def statuses(rotation)
    rotation.reload.rotation_matches.order(:match_index).map { |rm| rm.progress_status(rotation.current_match_index) }
  end
end
