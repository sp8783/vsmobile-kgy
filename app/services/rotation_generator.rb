class RotationGenerator
  MAX_MATCHES_PER_ROTATION = 50

  def initialize(players)
    @players = players.sort_by(&:id) # Ensure consistent ordering
    @player_count = @players.size
    @matches = []

    # Statistics tracking
    @pair_counts = Hash.new(0)         # {[player1_id, player2_id] => count}
    @opponent_counts = Hash.new(0)     # {[player1_id, opponent_id] => count}
    @match_counts = Hash.new(0)        # {player_id => count}
  end

  def generate
    case @player_count
    when 4
      generate_4_players
    when 5
      generate_5_players
    when 6
      generate_6_players
    when 7
      generate_7_players
    when 8
      generate_8_players
    else
      raise "Unsupported player count: #{@player_count}. Supported: 4-8 players."
    end

    @matches
  end

  private

  # 4 players: Fixed rotation template (12 matches)
  # First player in team1 is always the streaming player
  def generate_4_players
    # Fixed template based on user specification
    # Format: [[team1_p1_idx, team1_p2_idx], [team2_p1_idx, team2_p2_idx]]
    # First player in team1 is always the streaming player
    template = [
      [[0, 1], [2, 3]],  # A B vs C D
      [[1, 0], [2, 3]],  # B A vs C D
      [[2, 3], [0, 1]],  # C D vs A B
      [[3, 2], [0, 1]],  # D C vs A B
      [[0, 2], [1, 3]],  # A C vs B D
      [[2, 0], [1, 3]],  # C A vs B D
      [[1, 3], [0, 2]],  # B D vs A C
      [[3, 1], [0, 2]],  # D B vs A C
      [[0, 3], [1, 2]],  # A D vs B C
      [[3, 0], [1, 2]],  # D A vs B C
      [[1, 2], [0, 3]],  # B C vs A D
      [[2, 1], [0, 3]]   # C B vs A D
    ]

    template.each_with_index do |match, idx|
      team1 = [@players[match[0][0]], @players[match[0][1]]]
      team2 = [@players[match[1][0]], @players[match[1][1]]]
      add_match(idx, team1, team2)
    end
  end

  # 5 players: Fixed rotation template (15 matches)
  # One player sits out each match
  # Player 0 (A) always sits in streaming position when in Team 1
  def generate_5_players
    # Fixed template based on user specification
    # Format: [[team1_p1_idx, team1_p2_idx], [team2_p1_idx, team2_p2_idx]]
    # First player in team1 is always the streaming player
    template = [
      [[0, 1], [2, 3]],  # A B vs C D
      [[2, 0], [1, 3]],  # C A vs B D
      [[3, 0], [1, 2]],  # D A vs B C
      [[0, 2], [1, 4]],  # A C vs B E
      [[4, 0], [1, 2]],  # E A vs B C
      [[1, 0], [4, 2]],  # B A vs E C
      [[3, 0], [1, 4]],  # D A vs B E
      [[4, 0], [1, 3]],  # E A vs B D
      [[1, 0], [4, 3]],  # B A vs E D
      [[0, 4], [2, 3]],  # A E vs C D
      [[2, 0], [4, 3]],  # C A vs E D
      [[3, 0], [4, 2]],  # D A vs E C
      [[2, 1], [3, 4]],  # C B vs D E
      [[1, 3], [2, 4]],  # B D vs C E
      [[4, 1], [2, 3]]   # E B vs C D
    ]

    template.each_with_index do |match, idx|
      team1 = [@players[match[0][0]], @players[match[0][1]]]
      team2 = [@players[match[1][0]], @players[match[1][1]]]
      add_match(idx, team1, team2)
    end
  end

  # 6 players: Fixed rotation template (45 matches)
  # First player in team1 is always the streaming player
  def generate_6_players
    # Fixed template based on user specification
    # Format: [[team1_p1_idx, team1_p2_idx], [team2_p1_idx, team2_p2_idx]]
    # First player in team1 is always the streaming player
    template = [
      [[0, 1], [2, 3]],  # A B vs C D
      [[1, 0], [4, 5]],  # B A vs E F
      [[3, 2], [4, 5]],  # D C vs E F
      [[4, 1], [0, 2]],  # E B vs A C
      [[3, 5], [0, 2]],  # D F vs A C
      [[5, 3], [1, 4]],  # F D vs B E
      [[0, 3], [1, 5]],  # A D vs B F
      [[3, 0], [2, 4]],  # D A vs C E
      [[1, 5], [2, 4]],  # B F vs C E
      [[1, 3], [0, 4]],  # B D vs A E
      [[2, 5], [0, 4]],  # C F vs A E
      [[5, 2], [1, 3]],  # F C vs B D
      [[2, 1], [0, 5]],  # C B vs A F
      [[3, 4], [0, 5]],  # D E vs A F
      [[4, 3], [1, 2]],  # E D vs B C
      [[0, 1], [2, 4]],  # A B vs C E
      [[1, 0], [3, 5]],  # B A vs D F
      [[4, 2], [3, 5]],  # E C vs D F
      [[0, 2], [3, 4]],  # A C vs D E
      [[2, 0], [1, 5]],  # C A vs B F
      [[3, 4], [1, 5]],  # D E vs B F
      [[5, 4], [0, 3]],  # F E vs A D
      [[1, 2], [0, 3]],  # B C vs A D
      [[2, 1], [4, 5]],  # C B vs E F
      [[0, 4], [2, 3]],  # A E vs C D
      [[4, 0], [1, 5]],  # E A vs B F
      [[3, 2], [1, 5]],  # D C vs B F
      [[0, 5], [2, 4]],  # A F vs C E
      [[5, 0], [1, 3]],  # F A vs B D
      [[2, 4], [1, 3]],  # C E vs B D
      [[4, 3], [0, 1]],  # E D vs A B
      [[2, 5], [0, 1]],  # C F vs A B
      [[5, 2], [3, 4]],  # F C vs D E
      [[1, 3], [0, 2]],  # B D vs A C
      [[4, 5], [0, 2]],  # E F vs A C
      [[5, 4], [1, 3]],  # F E vs B D
      [[0, 3], [1, 4]],  # A D vs B E
      [[3, 0], [2, 5]],  # D A vs C F
      [[4, 1], [2, 5]],  # E B vs C F
      [[2, 1], [0, 4]],  # C B vs A E
      [[3, 5], [0, 4]],  # D F vs A E
      [[5, 3], [1, 2]],  # F D vs B C
      [[0, 5], [1, 4]],  # A F vs B E
      [[5, 0], [2, 3]],  # F A vs C D
      [[1, 4], [2, 3]]   # B E vs C D
    ]

    template.each_with_index do |match, idx|
      team1 = [@players[match[0][0]], @players[match[0][1]]]
      team2 = [@players[match[1][0]], @players[match[1][1]]]
      add_match(idx, team1, team2)
    end
  end

  # 7 players: Fixed rotation template (21 matches)
  # One player sits out each match
  # First player in team1 is always the streaming player
  def generate_7_players
    # Fixed template based on user specification
    # Format: [[team1_p1_idx, team1_p2_idx], [team2_p1_idx, team2_p2_idx]]
    # First player in team1 is always the streaming player
    template = [
      [[2, 3], [0, 1]],  # C D vs A B
      [[4, 5], [0, 1]],  # E F vs A B
      [[5, 4], [2, 3]],  # F E vs C D
      [[0, 2], [3, 4]],  # A C vs D E
      [[2, 0], [6, 1]],  # C A vs G B
      [[3, 4], [6, 1]],  # D E vs G B
      [[0, 3], [5, 6]],  # A D vs F G
      [[3, 0], [1, 2]],  # D A vs B C
      [[6, 5], [1, 2]],  # G F vs B C
      [[0, 4], [5, 1]],  # A E vs F B
      [[4, 0], [6, 2]],  # E A vs G C
      [[1, 5], [6, 2]],  # B F vs G C
      [[6, 3], [0, 5]],  # G D vs A F
      [[1, 4], [0, 5]],  # B E vs A F
      [[4, 1], [6, 3]],  # E B vs G D
      [[2, 4], [0, 6]],  # C E vs A G
      [[5, 3], [0, 6]],  # F D vs A G
      [[3, 5], [2, 4]],  # D F vs C E
      [[1, 3], [2, 5]],  # B D vs C F
      [[6, 4], [1, 3]],  # G E vs B D
      [[5, 2], [6, 4]]   # F C vs G E
    ]

    template.each_with_index do |match, idx|
      team1 = [@players[match[0][0]], @players[match[0][1]]]
      team2 = [@players[match[1][0]], @players[match[1][1]]]
      add_match(idx, team1, team2)
    end
  end

  # 8 players: Fixed rotation template (42 matches)
  # First player in team1 is always the streaming player
  def generate_8_players
    # Fixed template based on user specification
    # Format: [[team1_p1_idx, team1_p2_idx], [team2_p1_idx, team2_p2_idx]]
    # First player in team1 is always the streaming player
    # A=0, B=1, C=2, D=3, E=4, F=5, G=6, H=7
    template = [
      [[0, 1], [2, 3]],  # A B vs C D
      [[1, 0], [4, 5]],  # B A vs E F
      [[6, 7], [0, 1]],  # G H vs A B
      [[7, 6], [2, 3]],  # H G vs C D
      [[4, 5], [2, 3]],  # E F vs C D
      [[5, 4], [6, 7]],  # F E vs G H
      [[3, 1], [0, 2]],  # D B vs A C
      [[2, 0], [4, 6]],  # C A vs E G
      [[0, 2], [5, 7]],  # A C vs F H
      [[1, 3], [5, 7]],  # B D vs F H
      [[6, 4], [1, 3]],  # G E vs B D
      [[7, 5], [4, 6]],  # H F vs E G
      [[2, 1], [0, 3]],  # C B vs A D
      [[4, 7], [0, 3]],  # E H vs A D
      [[3, 0], [6, 5]],  # D A vs G F
      [[5, 6], [1, 2]],  # F G vs B C
      [[1, 2], [4, 7]],  # B C vs E H
      [[6, 5], [4, 7]],  # G F vs E H
      [[0, 4], [1, 5]],  # A E vs B F
      [[4, 0], [2, 6]],  # E A vs C G
      [[7, 3], [0, 4]],  # H D vs A E
      [[5, 1], [3, 7]],  # F B vs D H
      [[2, 6], [1, 5]],  # C G vs B F
      [[3, 7], [2, 6]],  # D H vs C G
      [[1, 4], [0, 5]],  # B E vs A F
      [[0, 5], [2, 7]],  # A F vs C H
      [[5, 0], [3, 6]],  # F A vs D G
      [[6, 3], [1, 4]],  # G D vs B E
      [[4, 1], [2, 7]],  # E B vs C H
      [[3, 6], [2, 7]],  # D G vs C H
      [[7, 1], [0, 6]],  # H B vs A G
      [[2, 4], [0, 6]],  # C E vs A G
      [[0, 6], [3, 5]],  # A G vs D F
      [[1, 7], [3, 5]],  # B H vs D F
      [[7, 1], [2, 4]],  # H B vs C E
      [[2, 4], [3, 5]],  # C E vs D F
      [[6, 1], [0, 7]],  # G B vs A H
      [[5, 2], [0, 7]],  # F C vs A H
      [[4, 3], [0, 7]],  # E D vs A H
      [[3, 4], [1, 6]],  # D E vs B G
      [[6, 1], [2, 5]],  # G B vs C F
      [[5, 2], [3, 4]]   # F C vs D E
    ]

    template.each_with_index do |match, idx|
      team1 = [@players[match[0][0]], @players[match[0][1]]]
      team2 = [@players[match[1][0]], @players[match[1][1]]]
      add_match(idx, team1, team2)
    end
  end

  # Find the most balanced match based on current statistics
  def find_most_balanced_match
    best_match = nil
    best_score = Float::INFINITY

    # Try ALL team combinations (not sampled)
    @players.combination(2).to_a.each do |team1|
      remaining = @players - team1
      remaining.combination(2).to_a.each do |team2|
        next if (team1 & team2).any? # Teams must not overlap

        score = calculate_match_imbalance(team1, team2)

        if score < best_score
          best_score = score
          best_match = { team1: team1, team2: team2 }
        end
      end
    end

    best_match
  end

  # Calculate how much imbalance this match would create
  def calculate_match_imbalance(team1, team2)
    imbalance = 0

    all_players = team1 + team2

    # Check pair imbalance - heavily weight to ensure even pair distribution
    pair_key1 = player_pair_key(team1[0], team1[1])
    pair_key2 = player_pair_key(team2[0], team2[1])

    imbalance += (@pair_counts[pair_key1] ** 3) * 10
    imbalance += (@pair_counts[pair_key2] ** 3) * 10

    # Check opponent imbalance
    team1.each do |p1|
      team2.each do |p2|
        opp_key = player_pair_key(p1, p2)
        imbalance += (@opponent_counts[opp_key] ** 2) * 5
      end
    end

    # Check match count imbalance
    all_players.each do |player|
      imbalance += (@match_counts[player.id] ** 2)
    end

    imbalance
  end

  # Generate random teams (fallback - should not be needed)
  def generate_random_teams
    shuffled = @players.shuffle
    return nil if shuffled.size < 4

    team1 = shuffled[0..1]
    team2 = shuffled[2..3]

    [team1, team2]
  end

  def add_match(index, team1, team2)
    @matches << {
      match_index: index,
      team1_player1: team1[0],
      team1_player2: team1[1],
      team2_player1: team2[0],
      team2_player2: team2[1]
    }

    # Update statistics
    update_statistics(team1, team2)
  end

  def update_statistics(team1, team2)
    # Update pair counts
    @pair_counts[player_pair_key(team1[0], team1[1])] += 1
    @pair_counts[player_pair_key(team2[0], team2[1])] += 1

    # Update opponent counts
    team1.each do |p1|
      team2.each do |p2|
        @opponent_counts[player_pair_key(p1, p2)] += 1
      end
    end

    # Update match counts
    (team1 + team2).each do |player|
      @match_counts[player.id] += 1
    end
  end

  def player_pair_key(player1, player2)
    [player1.id, player2.id].sort
  end

  # Get statistics for analysis
  def statistics
    {
      total_matches: @matches.size,
      match_counts: @match_counts,
      pair_counts: @pair_counts,
      opponent_counts: @opponent_counts
    }
  end
end
