#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraperwiki'
require 'wikidata/fetcher'

module Wikisnakker
  class Item
    SKIP = %i(P17 P18 P910).to_set
    WANT = {
      P31:  :type,
      P571: :start_date,
      P576: :end_date,
    }.freeze

    def data
      unknown_properties.each do |p|
        warn "Unknown property for #{id}: #{p} = #{send(p).value}"
      end

      base_data.merge(wanted_data)
    end

    private

    def base_data
      {
        id:    id,
        label: label(:en),
      }
    end

    def unknown_properties
      properties.reject { |p| SKIP.include?(p) || WANT.key?(p) }
    end

    def wanted_properties
      properties.select { |p| WANT.key?(p) }
    end

    def wanted_data
      wanted_properties.map { |p| [WANT[p], send(p).value.to_s] }.to_h
    end
  end
end

module Wikidata
  require 'wikisnakker'

  class Areas
    def initialize(ids:)
      @ids = ids
    end

    def areas
      wikisnakker_items.flat_map(&:data).compact
    end

    private

    attr_reader :ids

    def wikisnakker_items
      @wsitems ||= Wikisnakker::Item.find(ids)
    end
  end
end

query = <<QUERY
  SELECT DISTINCT ?item
  WHERE
  {
    ?item wdt:P31/wdt:P279* wd:Q192611 .
    ?item wdt:P17 wd:Q%s .
  }
QUERY

wanted = EveryPolitician::Wikidata.sparql(query % 191)
raise 'No ids' if wanted.empty?

data = Wikidata::Areas.new(ids: wanted).areas
ScraperWiki.save_sqlite(%i(id), data)
