require 'sketchup.rb'

require 'ex_sunservice/execution'

module Examples::SunOverlay

  # load 'ex_sunservice/main.rb'
  # unless file_loaded?(__FILE__)
  #   menu = UI.menu('Plugins')
  #   menu.add_item('Sun Analysis') { self.analyse_sun }
  # end

  # Examples::SunOverlay.register_overlays
  def self.register_overlays
    model = Sketchup.active_model
    return unless model.respond_to?(:overlays)

    @overlays = SunAnalysisOverlay.new
    model.overlays.add(@overlays)
    nil
  end

  def self.boot
    self.register_overlays
  end

  unless defined?(OVERLAY)
    OVERLAY = if defined?(Sketchup::Overlay)
      Sketchup::Overlay
    else
      require 'ex_sunservice/mock_overlay'
      MockOverlay
    end
  end

  class SunAnalysisOverlay < OVERLAY

    SUNLIT_COLOR = Sketchup::Color.new(255, 128, 0, 64)

    attr_reader :overlay_id, :name

    def initialize
      super
      @overlay_id = 'thomthom.sunanalysis'.freeze
      @name = 'Sun Analysis'.freeze

      @triangles = []
    end

    def start(view)
      start_observing_app
      start_observing_model(view.model)
    end

    def stop(view)
      stop_observing_model(view.model)
      stop_observing_app
    end

    def draw(view)
      view.drawing_color = SUNLIT_COLOR
      view.draw(GL_TRIANGLES, @triangles) unless @triangles.empty?
    end

    def onTransactionCommit(model)
      reanalyze
    end
    def onTransactionEmpty(model)
      reanalyze
    end
    def onTransactionRedo(model)
      reanalyze
    end
    def onTransactionUndo(model)
      reanalyze
    end

    def onShadowInfoChanged(shadow_info, type)
      reanalyze
    end

    # @param [Sketchup::Model]
    def onNewModel(model)
      start_observing_model(model)
    end
    # @param [Sketchup::Model]
    def onOpenModel(model)
      start_observing_model(model)
    end

    private

    def reanalyze
      @reanalyze ||= Execution::Debounce.new(0.05)
      @reanalyze.call do
        analyze
        Sketchup.active_model.active_view.invalidate
      end
    end

    def analyze
      triangles = []
      model = Sketchup.active_model
      sun_direction = model.shadow_info['SunDirection']
      model.active_entities.grep(Sketchup::Face) { |face|
        lit_by_sun = (face.normal % sun_direction) > 0
        next unless lit_by_sun

        mesh = face.mesh
        (1..mesh.count_polygons).each { |i|
          triangle = mesh.polygon_points_at(i)
          triangles.concat(triangle)
        }
      }
      @triangles = triangles
    end

    def start_observing_app
      # TODO: Need to figure out how model overlays works with Mac's MDI.
      return unless Sketchup.platform == :platform_win
      Sketchup.remove_observer(self)
      Sketchup.add_observer(self)
    end

    def stop_observing_app
      return unless Sketchup.platform == :platform_win
      Sketchup.remove_observer(self)
    end

    # @param [Sketchup::Model]
    def start_observing_model(model)
      stop_observing_model(model)
      model.add_observer(self)
      model.shadow_info.add_observer(self)
      analyze
    end

    # @param [Sketchup::Model]
    def stop_observing_model(model)
      model.shadow_info.remove_observer(self)
      model.remove_observer(self)
    end

  end

  unless file_loaded?(__FILE__)
    self.boot
  end

  file_loaded(__FILE__)

end # module
