namespace :maintenance do
  desc "Fix matches missing rotation_match_id (one-shot task for Issue #57)"
  task fix_rotation_match_links: :environment do
    fixed = 0

    RotationMatch.where.not(match_id: nil).find_each do |rm|
      match = Match.find_by(id: rm.match_id)
      next unless match
      next unless match.rotation_match_id.nil?

      match.update_column(:rotation_match_id, rm.id)
      fixed += 1
    end

    puts "Fixed #{fixed} match(es) with missing rotation_match_id."
  end
end
