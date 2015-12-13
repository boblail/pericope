module CLI
  class Command



    def initialize(name, description, &block)
      @name, @description, @block = name, description, &block
    end



    attr_reader :name, :description



    def execute
      @block.call
    end



  end
end
