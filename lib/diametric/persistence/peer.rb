require 'diametric/persistence/common'

module Diametric
  module Persistence
    module Peer

      def save(connection=nil)
        return false unless valid?
        return true unless changed?
        connection ||= Diametric::Persistence::Peer.connect

        parsed_data = []
        parse_tx_data(tx_data, parsed_data)

        map = connection.transact(parsed_data).get

        resolve_changes([self], map)

        map
      end

      def resolve_tempid(map, id)
        if id.to_s =~ /-\d+/
          return Diametric::Persistence::Peer.resolve_tempid(map, id)
        end
        return id
      end

      def parse_tx_data(data, result)
        queue = []
        data.each do |c_data|
          if c_data.is_a? Hash
            parse_hash_data(c_data, result, queue)
          elsif c_data.is_a? Array
            parse_array_data(c_data, result)
          end
        end
        parse_tx_data(queue, result) unless queue.empty?
      end

      def parse_hash_data(c_hash, result, queue)
          hash = {}
          c_hash.each do |c_key, c_value|
            if c_value.respond_to?(:tx_data)
              if c_value.tx_data.empty?
                hash[c_key] = c_value.dbid
              else
                c_value.dbid = c_value.tempid
                hash[c_key] = c_value.dbid
                queue << c_value.tx_data.first
              end
            elsif c_value.is_a? Set
              set_value = Set.new
              c_value.each do |s|
                if s.respond_to?(:tx_data) && s.tx_data.empty?
                  set_value << s.dbid
                elsif s.respond_to?(:tx_data)
                  set_value << s.tx_data[":db/id"]
                  parsed_tx_data(s, result)
                else
                  set_value << s
                end
              end
              hash[c_key] = set_value
            elsif c_value.respond_to?(:eid)
              hash[c_key] = c_value.eid
            else
              hash[c_key] = c_value
            end
          end
          result << hash
      end

      def parse_array_data(c_array, result)
        array = []
        c_array.each do |c_value|
          if c_value.respond_to?(:to_a)
            a_values = []
            c_value.to_a.each do |a_value|
              if a_value.respond_to?(:tx_data) && a_value.tx_data.empty?
                a_values << a_value.dbid
              else
                a_values << a_value
              end
            end
            array << a_values
          else
            array << c_value
          end
        end
        result << array
      end

      def resolve_changes(parents, map)
        queue = []
        parents.each do |child|
          child.attributes.each do |a_key, a_val|
            if a_val.respond_to?(:tx_data)
              queue << a_val
            end

            if a_val.respond_to?(:each)
              a_val.each do |child|
                if child.respond_to?(:tx_data)
                  queue << child
                end
              end
            end

          end
          child.instance_variable_set("@previously_changed", child.changes)
          child.changed_attributes.clear
          child.dbid = resolve_tempid(map, child.dbid)
        end
        resolve_changes(queue, map) unless queue.empty?
      end

      def retract_entity(dbid)
        Diametric::Persistence::Peer.retract_entity(dbid)
      end

      def method_missing(method_name, *args, &block)
        result = /(.+)_from_this_(.+)/.match(method_name)
        if result
          query_string = ":#{result[1]}/_#{result[2]}"
          entities = Diametric::Persistence::Peer.reverse_q(args[0].db, self.dbid, query_string)
          entities.collect {|e| self.class.reify(e, args[0])}
        else
          super
        end
      end

      module ClassMethods
        def get(dbid, connection=nil, resolve=false)
          entity = self.new
          dbid = dbid.to_i if dbid.is_a?(String)
          connection ||= Diametric::Persistence::Peer.connect
          entity = self.reify(dbid, connection, resolve)
          entity
        end

        def q(query, args, conn_or_db=nil)
          conn_or_db ||= Diametric::Persistence::Peer.connect
          if conn_or_db.is_a?(Diametric::Persistence::Connection)
            db = conn_or_db.db
          else
            db = conn_or_db
          end
          Diametric::Persistence::Peer.q(query, db, args)
        end
      end
    end
  end
end
