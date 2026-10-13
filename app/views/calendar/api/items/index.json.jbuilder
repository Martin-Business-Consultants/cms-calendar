# frozen_string_literal: true

json.from @from
json.to @to
json.items @items, partial: "calendar/api/items/item", as: :item
