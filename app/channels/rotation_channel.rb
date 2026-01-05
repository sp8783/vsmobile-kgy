class RotationChannel < ApplicationCable::Channel
  def subscribed
    rotation = Rotation.find(params[:rotation_id])
    stream_for rotation
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
