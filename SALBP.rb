# Ruby 2.6.6

require 'pry'

class Util
  class << self
    def read_orders_from_file(filename)
      orders = []
      File.readlines(filename).each do |line|
        order_data, prev_orders = line.split(';')
        order_number, order_duration, *next_orders = order_data.split(' ')
        orders.push Order.new(order_number.to_i, order_duration.to_i, prev_orders.map(&:to_i), next_orders.map(&:to_i))
      end
      orders
    end

    def read_orders_from_var(var)
      orders = []
      var.split("\n").each do |line|
        order_data, prev_orders = line.split(';')
        order_number, order_duration, *next_orders = order_data.split(' ')
        prev_orders = prev_orders.to_s.split(' ').map(&:to_i)
        orders.push Order.new(order_number.to_i, order_duration.to_i, prev_orders, next_orders.map(&:to_i))
      end
      orders
    end
    
    def map_next_and_prev_orders(orders)
      orders.map do |order|
        order.nexts = order.nexts.map do |next_order_number|
          orders.find { |o| o.number == next_order_number }
        end
        order.prevs = order.prevs.map do |prev_order_number|
          orders.find { |o| o.number == prev_order_number }
        end
      end
    end
  end
end

class Order
  attr_accessor :number, :duration, :prevs, :nexts, :rpw_duration

  def initialize(number, duration, prevs, nexts)
    @number = number
    @duration = duration
    @prevs = prevs
    @nexts = nexts
    @rpw_duration = duration
  end
  
  def can_marshal?(marshaled)
    return true if prevs.none?

    prevs.map { |prev| marshaled.find { |o| o.number == prev.number } }.all?
  end
end

class Result
  class Station
    attr_accessor :orders, :c_time

    def initialize(c_time)
      @orders = []
      @c_time = c_time
    end

    def can_fit?(duration)
      orders.sum(&:duration) + duration <= c_time
    end
  end

  attr_accessor :stations, :c_time

  def initialize(c_time)
    @stations = []
    @c_time = c_time
  end

  def marshal(orders)
    to_marshal = orders.dup
    marshaled = []

    station = new_station
    while(to_marshal.any?) do
      at_least_one_marshaled = false
      to_marshal.each do |order|
        if order.can_marshal?(marshaled) 
          if station.can_fit?(order.duration)
            station.orders.push order
            marshaled.push order
            to_marshal.delete_if { |o| o.number == order.number }
            at_least_one_marshaled = true
            break
          end
        end
      end
      station = new_station unless at_least_one_marshaled
    end

    def display 
      stations.each_with_index do |station, i|
        puts "  ST(#{i + 1}) " + station.orders.map { |o| "#{o.number}(#{o.duration})" }.join(' ')
      end
      puts "  LE = #{line_eff}%"
      puts "  SI = #{smoothness_ind}"
      puts "  T = #{line_time}"
    end
  end

  def new_station
    station = Station.new(c_time)
    stations.push station
    station
  end

  def line_eff
    total_duration = stations.sum do |station|
      station.orders.sum(&:duration)
    end

    (total_duration.to_f / (stations.count * c_time) * 100).round(2)
  end

  def smoothness_ind
    durations = stations.map do |station|
      station.orders.sum(&:duration)
    end

    sum_of_squared_diffs = durations.sum do |duration|
      (c_time - duration) ** 2
    end

    Math.sqrt(sum_of_squared_diffs).round(2)
  end

  def line_time
    stations.count * c_time
  end
end

class Solver
  class << self
    def marshal(method, base_orders, workstations)
      raise "Invalid method: #{method}" unless %{RPW WET}.include? method

      orders = send "order_#{method.downcase}", base_orders
      puts "Order for #{method}:" + orders.map(&:number).join(', ')
      c_time_base = orders.sum(&:duration) / workstations

      c_time = c_time_base
      while(1) do 
        result = Result.new(c_time)
        result.marshal(orders)
        puts "#{method}, c = #{c_time}"
        result.display
        break if result.stations.count <= workstations
        puts ''
        c_time += 1
      end
    end

    private

    def order_wet(orders)
      orders.sort_by { |o| o.duration }.reverse
    end

    def order_rpw(base_orders)
      orders = base_orders.sort_by { |o| o.number }.reverse
      
      orders = orders.map do |order|
        unless order.nexts.none?
          order.rpw_duration = order.rpw_duration + order.nexts.map(&:rpw_duration).max
        end
        order
      end

      orders.sort_by { |o| o.rpw_duration }.reverse
    end
  end
end


## Configuration

WORKSTATIONS = 4


# Tutaj podać dane np. tak:
# given_orders <<-eos
# 1 7 2 ;
# 2 4 3 ; 1
# eos

given_orders = <<-eos
1 3 3;
2 6 4;
3 8 6; 1
4 4 7; 2
5 7 7;
6 2 8; 3
7 3 8; 4 5
8 6 9 10 11; 7 6
9 9 12; 8
10 5 12; 8
11 2 13; 8
12 7 13; 10 9
13 3; 11 12


eos

## Program
orders = if given_orders.strip.empty?
           Util.read_orders_from_file(ARGV.first)
         else
           Util.read_orders_from_var(given_orders.strip)
         end

Util.map_next_and_prev_orders(orders)

Solver.marshal('WET', orders, WORKSTATIONS)

puts ''

Solver.marshal('RPW', orders, WORKSTATIONS)
