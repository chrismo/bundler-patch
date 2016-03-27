module Bundler::Patch
  class AdvisoryConsolidator
    def initialize(options={}, all_ads=nil)
      @options = options
      @all_ads = all_ads || [].tap do |a|
        a << Bundler::Advise::Advisories.new unless options[:skip_bundler_advise]
        a << Bundler::Advise::Advisories.new(dir: options[:advisory_db_path], repo: nil) if options[:advisory_db_path]
      end
    end

    def vulnerable_gems
      @all_ads.map do |ads|
        ads.update if ads.repo
        Bundler::Advise::GemAdviser.new(advisories: ads).scan_lockfile
      end.flatten.map do |advisory|
        patched = advisory.patched_versions.map do |pv|
          pv.requirements.map { |_, v| v.to_s }
        end.flatten
        Gemfile.new(gem_name: advisory.gem, patched_versions: patched)
      end.group_by do |gemfile|
        gemfile.gem_name
      end.map do |_, gemfiles|
        consolidate_gemfiles(gemfiles)
      end.flatten
    end

    private

    def consolidate_gemfiles(gemfiles)
      gemfiles if gemfiles.length == 1
      all_gem_names = gemfiles.map(&:gem_name).uniq
      raise 'Must be all same gem name' unless all_gem_names.length == 1
      highest_minor_patched = gemfiles.map do |g|
        g.patched_versions
      end.flatten.group_by do |v|
        Gem::Version.new(v).segments[0..1].join('.')
      end.map do |_, all|
        all.sort.last
      end
      Gemfile.new(gem_name: all_gem_names.first, patched_versions: highest_minor_patched)
    end
  end
end