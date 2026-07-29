module TurboBroadcastHelper
  def turbo_stream_broadcasts_for(streamable)
    ActionCable.server.pubsub.broadcasts(streamable.to_gid_param).map { JSON.parse(it) }
  end
end
