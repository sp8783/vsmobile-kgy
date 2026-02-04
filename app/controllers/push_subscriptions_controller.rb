class PushSubscriptionsController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, only: [ :create, :destroy, :unsubscribe_all ]

  # GET /vapid_public_key
  def vapid_public_key
    render json: { vapid_public_key: Rails.application.credentials.dig(:vapid, :public_key) }
  end

  # POST /push_subscriptions
  def create
    subscription = current_user.push_subscriptions.find_or_initialize_by(
      endpoint: subscription_params[:endpoint]
    )

    subscription.assign_attributes(
      p256dh_key: subscription_params[:p256dh_key],
      auth_key: subscription_params[:auth_key],
      user_agent: request.user_agent,
      last_used_at: Time.current
    )

    if subscription.save
      render json: { status: "subscribed", id: subscription.id }, status: :created
    else
      render json: { errors: subscription.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /push_subscriptions/:id
  def destroy
    subscription = current_user.push_subscriptions.find_by(id: params[:id])

    if subscription&.destroy
      render json: { status: "unsubscribed" }, status: :ok
    else
      render json: { error: "Subscription not found" }, status: :not_found
    end
  end

  # DELETE /push_subscriptions/unsubscribe_all
  def unsubscribe_all
    current_user.push_subscriptions.destroy_all
    render json: { status: "all_unsubscribed" }, status: :ok
  end

  private

  def subscription_params
    params.require(:push_subscription).permit(:endpoint, :p256dh_key, :auth_key)
  end
end
