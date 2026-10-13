# frozen_string_literal: true

module Calendar
  module Api
    # /api/calendar/items: the calendar between ?from and ?to (default: this
    # month and the next), and items written, changed and deleted. Writing one
    # never schedules it: that's /schedule, which takes calendar:publish.
    class ItemsController < BaseController
      requires_capability "calendar:read", only: [:index, :show]
      requires_capability "calendar:write", only: [:create, :update, :destroy]

      def index
        from = (Date.parse(params[:from].to_s) rescue Date.current.beginning_of_month)
        to = (Date.parse(params[:to].to_s) rescue (from + 1.month).end_of_month)
        @items = Item.between(from.beginning_of_day, to.end_of_day).or(params[:unscheduled] ? Item.unscheduled : Item.none)
          .includes(deliveries: :channel).order(:scheduled_at).to_a
        @from = from
        @to = to
      end

      def show
        @item = Item.find(params[:id])
      end

      def create
        @item = Item.new(item_params.merge(user: Current.user, state: "draft"))
        @item.assign_channels(params.dig(:item, :channel_ids), texts)
        @item.save!
        render :show, status: :created
      end

      def update
        @item = Item.find(params[:id])
        return refuse("It's scheduled: take it off the schedule first") if @item.state.in?(%w[scheduled sending published])

        @item.assign_attributes(item_params)
        @item.assign_channels(params.dig(:item, :channel_ids), texts) if params.dig(:item, :channel_ids)
        @item.save!
        render :show
      end

      def destroy
        item = Item.find(params[:id])
        return refuse("It's gone out already") if item.state == "published"

        item.destroy!
        head :no_content
      end

      private

      def item_params = params.require(:item).permit(:title, :kind, :scheduled_at, :body, :link_url, :asset_id, :notes)
      def texts = params.dig(:item, :texts)&.permit!.to_h || {}
    end
  end
end
