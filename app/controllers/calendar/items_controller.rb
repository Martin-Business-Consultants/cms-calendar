# frozen_string_literal: true

module Calendar
  # The calendar: a month of items beside the open one (index), and an item
  # written or changed (new, edit). Scheduling, drafting, starting its record
  # and sending have controllers of their own.
  class ItemsController < ApplicationController
    requires_capability "calendar:read", only: :index
    requires_capability "calendar:write", only: [:new, :create, :edit, :update, :destroy]

    before_action :set_item, only: [:edit, :update, :destroy]

    def index
      @month = (Date.strptime(params[:month].to_s, "%Y-%m") rescue Date.current).beginning_of_month
      first = @month.beginning_of_week
      last = @month.end_of_month.end_of_week
      @days = (first..last).to_a
      @items = Item.between(first.beginning_of_day, last.end_of_day).includes(deliveries: :channel).order(:scheduled_at).group_by { it.scheduled_at.to_date }
      @item = Item.includes(deliveries: :channel).find_by(id: params[:item])
      @unscheduled = Item.unscheduled.order(created_at: :desc).limit(20).to_a
    end

    def new
      @item = Item.new(kind: params[:kind].presence_in(Item::KINDS.keys) || "social", scheduled_at: params[:on].presence&.then { Date.parse(it).in_time_zone.change(hour: 10) rescue nil })
      @item.assign_channels(Channel.connected.pluck(:id))
    end

    def create
      @item = Item.new(item_params.merge(user: Current.user, state: "draft"))
      @item.assign_channels(params.dig(:item, :channel_ids), texts)
      if @item.save
        redirect_to calendar_for(@item), notice: "Added “#{@item.title}”"
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      @item.assign_attributes(item_params)
      @item.assign_channels(params.dig(:item, :channel_ids), texts)
      if @item.save
        redirect_to calendar_for(@item), notice: "Saved"
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @item.destroy!
      redirect_to calendar_path(month: @item.scheduled_at&.strftime("%Y-%m")), notice: "Deleted “#{@item.title}”"
    end

    private

    def set_item = @item = Item.find(params[:id])

    def item_params
      params.require(:item).permit(:title, :kind, :scheduled_at, :body, :link_url, :asset_id, :notes).tap do |attributes|
        attributes[:asset_id] = nil if attributes[:asset_id].blank?
      end
    end

    def texts = params.dig(:item, :texts)&.permit!.to_h || {}
  end
end
