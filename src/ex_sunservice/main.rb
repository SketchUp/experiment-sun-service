require 'sketchup.rb'

require 'ex_sunservice/execution'

module Examples::SunService

  unless file_loaded?(__FILE__)
    menu = UI.menu('Plugins')
    menu.add_item('Sun Analysis') { self.analyse_sun }
  end

  def self.analyse_sun
    service = SunAnalysisService.new
    model = Sketchup.active_model
    model.services.add(service)
    model.active_view.invalidate
  end

  class SunAnalysisService < Sketchup::ModelService

    SUNLIT_COLOR = Sketchup::Color.new(255, 128, 0, 64)

    def initialize
      super('SunAnalysis')

      @triangles = []

      model = Sketchup.active_model
      model.add_observer(self)
      model.shadow_info.add_observer(self)

      analyze
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

  end

end # module
