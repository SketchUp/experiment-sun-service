require 'sketchup.rb'

require 'ex_sunservice/execution'

module Examples::SunOverlay

  class AppObserver < Sketchup::AppObserver

    def expectsStartupModelNotifications
      true
    end

    def register_overlay(model)
      overlay = SunAnalysisOverlay.new
      begin
        model.overlays.add(overlay)
      rescue ArgumentError => error
        # If the overlay was already registered.
        warn error
      end
    end
    alias_method :onNewModel, :register_overlay
    alias_method :onOpenModel, :register_overlay

  end

  # Examples::SunOverlay.register_overlays
  def self.register_overlays
    model = Sketchup.active_model
    return unless model.respond_to?(:overlays)

    observer = AppObserver.new
    Sketchup.add_observer(observer)

    # In the case of installing or enabling the extension we need to
    # register the overlay.
    model = Sketchup.active_model
    observer.register_overlay(model) if model

    nil
  end

  def self.boot
    self.register_overlays
  end

  class SunAnalysisOverlay < Sketchup::Overlay

    SUNLIT_COLOR = Sketchup::Color.new(255, 128, 0, 64)

    def initialize
      super('thomthom.sunanalysis', 'Sun Analysis')

      @triangles = []
    end

    def start
      start_observing_app
      start_observing_model(Sketchup.active_model)
    end

    def stop
      stop_observing_model(Sketchup.active_model)
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
      Sketchup.remove_observer(self)
      Sketchup.add_observer(self)
    end

    def stop_observing_app
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
      return if model.nil? # Mac when model is closed.

      model.shadow_info.remove_observer(self)
      model.remove_observer(self)
    end

  end if defined?(Sketchup::Overlay)

  unless file_loaded?(__FILE__)
    self.boot
  end

  file_loaded(__FILE__)

end # module
