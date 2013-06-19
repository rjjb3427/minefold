# should be run about once a day

class DeleteOldSnapshotsJob < Job
  @queue = :low

  def perform
    Server.unscoped.where('deleted_at > ? and deleted_at < ?', 16.days.ago, 14.days.ago).each do |s|
      PartyCloud::Server.new(s.party_cloud_id).delete_all_snapshots!
    end
  end
end