require_relative '../../spec_helper'

describe ConservativeDefinition do
  before do
    @bf = BundlerFixture.new
    ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
  end

  after do
    ENV['BUNDLE_GEMFILE'] = nil
    @bf.clean_up
  end

  def lockfile_spec_version(gem_name)
    @bf.parsed_lockfile_spec(gem_name).version.to_s
  end

  context 'conservative update' do
    def setup_lockfile
      Dir.chdir(@bf.dir) do
        @bf.create_lockfile(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('bar', '1.1.2'),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('quux', '0.0.4'),
          ], ensure_sources: false)
        yield
      end
    end

    def test_conservative_update(gems_to_update, options, bundler_def)
      gem_patches = Array(gems_to_update).map do |gem_name|
        gem_name.is_a?(String) ? GemPatch.new(gem_name: gem_name) : gem_name
      end
      prep = DefinitionPrep.new(bundler_def, gem_patches, options).tap { |p| p.prep }
      prep.bundler_def.tap { |bd| bd.lock(File.join(Dir.pwd, 'Gemfile.lock')) }
    end

    it 'when updated gem has same dep req' do
      setup_lockfile do
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.5.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('bar', '1.1.2'),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('bar', '3.2.0'),
            @bf.create_spec('quux', '0.2.0'),
          ], ensure_sources: false, update_gems: 'foo')
        test_conservative_update('foo', {strict: true, minor: true}, bundler_def)

        lockfile_spec_version('bar').should == '1.1.3'
        lockfile_spec_version('foo').should == '2.5.0'
        lockfile_spec_version('quux').should == '0.0.4'
      end
    end

    it 'when updated gem has updated dep req increase major, strict and non-strict' do
      setup_lockfile do
        bundler_def = lambda { @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.5.0', [['bar', '~> 2.0']]),
            @bf.create_spec('bar', '1.1.2'),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('bar', '2.0.0'),
            @bf.create_spec('bar', '2.0.1'),
            @bf.create_spec('bar', '3.2.0'),
            @bf.create_spec('quux', '0.2.0'),
          ], ensure_sources: false, update_gems: 'foo') }

        test_conservative_update('foo', {strict: true, minor: true}, bundler_def.call)
        lockfile_spec_version('foo').should == '2.4.0'
        lockfile_spec_version('bar').should == '1.1.3'

        test_conservative_update('foo', {strict: false, minor: true}, bundler_def.call)
        lockfile_spec_version('foo').should == '2.5.0'
        lockfile_spec_version('bar').should == '2.0.1'
      end
    end

    it 'when updated gem has updated dep req increase major, not strict' do
      setup_lockfile do
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.5.0', [['bar', '~> 2.0']]),
            @bf.create_specs('bar', %w(1.1.2 1.1.3 2.0.0 2.0.1 3.2.0)),
            @bf.create_spec('quux', '0.2.0'),
          ], ensure_sources: false, update_gems: 'foo')
        test_conservative_update('foo', {strict: false, minor: true}, bundler_def)

        lockfile_spec_version('foo').should == '2.5.0'
        lockfile_spec_version('bar').should == '2.0.1'
        lockfile_spec_version('quux').should == '0.0.4'
      end
    end

    it 'updating multiple gems with same req' do
      setup_lockfile do
        gems_to_update = ['foo', 'quux']
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.5.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('bar', '1.1.2'),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('bar', '3.2.0'),
            @bf.create_spec('quux', '0.2.0'),
          ], ensure_sources: false, update_gems: gems_to_update)
        test_conservative_update(gems_to_update, {strict: true, minor: true}, bundler_def)

        lockfile_spec_version('bar').should == '1.1.3'
        lockfile_spec_version('foo').should == '2.5.0'
        lockfile_spec_version('quux').should == '0.2.0'
      end
    end

    it 'updates all conservatively' do
      setup_lockfile do
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.5.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('bar', '1.1.2'),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('bar', '1.1.4'),
            @bf.create_spec('bar', '3.2.0'),
            @bf.create_spec('quux', '0.2.0'),
          ], ensure_sources: false, update_gems: true)
        test_conservative_update([], {strict: true, minor: true}, bundler_def)

        lockfile_spec_version('bar').should == '1.1.4'
        lockfile_spec_version('foo').should == '2.5.0'
        lockfile_spec_version('quux').should == '0.2.0'
      end
    end

    it 'updates all conservatively when no upgrade exists' do
      setup_lockfile do
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('quux', '0.0.4'),
          ], ensure_sources: false, update_gems: true)
        test_conservative_update([], {strict: true, minor: true}, bundler_def)

        lockfile_spec_version('bar').should == '1.1.3'
        lockfile_spec_version('foo').should == '2.4.0'
        lockfile_spec_version('quux').should == '0.0.4'
      end
    end

    context 'no locked_spec exists' do
      def with_bundler_setup
        # bundler has special checks to not include itself in a lot of things
        Dir.chdir(@bf.dir) do
          @bf.create_lockfile(
            gem_dependencies: [@bf.create_dependency('foo')],
            source_specs: [
              @bf.create_spec('foo', '1.0.0', [['bundler', '>= 0']]),
              @bf.create_spec('bundler', '1.10.6'),
            ], ensure_sources: false)

          @bundler_def = @bf.create_definition(
            gem_dependencies: [@bf.create_dependency('foo')],
            source_specs: [
              @bf.create_spec('foo', '1.0.0', [['bundler', '>= 0']]),
              @bf.create_spec('foo', '1.0.1', [['bundler', '>= 0']]),
              @bf.create_spec('bundler', '1.10.6'),
            ], ensure_sources: false, update_gems: true)
          yield
        end
      end

      it 'does not explode when strict' do
        with_bundler_setup do
          test_conservative_update([], {strict: true}, @bundler_def)
        end
      end

      it 'does not explode when not strict' do
        with_bundler_setup do
          test_conservative_update([], {strict: false}, @bundler_def)
        end
      end
    end

    it 'should never increment major version' do
      setup_lockfile do
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '3.0.0', [['bar', '~> 2.0']]),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('bar', '2.0.0'),
            @bf.create_spec('quux', '0.0.4'),
          ], ensure_sources: false, update_gems: 'foo')
        test_conservative_update('foo', {strict: true, minor: true}, bundler_def)

        lockfile_spec_version('foo').should == '2.4.0'
        lockfile_spec_version('bar').should == '1.1.3'
        lockfile_spec_version('quux').should == '0.0.4'
      end
    end

    it 'strict mode should still go to the most recent release version' do
      setup_lockfile do
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.4.1', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.4.2', [['bar', '>= 1.0.4']]),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('quux', '0.0.4'),
          ], ensure_sources: false, update_gems: 'foo')
        test_conservative_update('foo', {strict: true}, bundler_def)

        lockfile_spec_version('foo').should == '2.4.2'
        lockfile_spec_version('bar').should == '1.1.3'
        lockfile_spec_version('quux').should == '0.0.4'
      end
    end

    it 'passing major increment in new_version in gems_to_update will not force a gem it' do
      setup_lockfile do
        gems_to_update = [GemPatch.new(gem_name: 'foo'), GemPatch.new(gem_name: 'quux', new_version: '2.4.0')]
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.5.0', [['bar', '>= 1.0.4']]),
            @bf.create_specs('bar', %w(1.1.2 1.1.3 3.2.0)),
            @bf.create_specs('quux', %w(0.0.4 0.2.0 2.4.0)),
          ], ensure_sources: false, update_gems: %w(foo quux))
        test_conservative_update(gems_to_update, {strict: false, minor: true}, bundler_def)

        lockfile_spec_version('bar').should == '1.1.3'
        lockfile_spec_version('foo').should == '2.5.0'
        lockfile_spec_version('quux').should == '0.2.0'
      end
    end

    it 'fixes up empty remotes in rubygems_aggregator' do
      # this test doesn't fail without the fixup code, but I already
      # commented I don't know the underlying cause, so better than nothing.
      gemfile = File.join(@bf.dir, 'Gemfile')
      File.open(gemfile, 'w') { |f| f.puts "source 'https://rubygems.org'" }
      setup_lockfile do
        bundler_def = test_conservative_update([], {strict: false}, nil)
        sources = bundler_def.send(:sources)
        sources.rubygems_remotes.length.should_not == 0
      end
    end

    it 'should spec out prefer_minimal'

    it 'needs to pass-through all install or update bundler options' #?

    it 'needs to cope with frozen setting'
    # see bundler-1.10.6/lib/bundler/installer.rb comments for explanation of frozen

    it 'what happens when a new version introduces a brand new gem' #?

    # make sure the docs match reality
    context 'BUNDLER.md' do
      def test_it(gems: [], options: {strict: false, minor: false})
        @bf.create_lockfile(gem_dependencies: @gem_deps, source_specs: @lock_source_specs, ensure_sources: false)

        bundler_def = @bf.create_definition(gem_dependencies: @gem_deps, source_specs: @source_specs,
                                            ensure_sources: false, update_gems: gems.empty? ? true : gems)
        test_conservative_update(gems, options, bundler_def)
      end

      context 'Two Gems' do
        before do
          @gem_deps = [@bf.create_dependency('foo')]
          @lock_source_specs = [
            @bf.create_specs('foo', %w(1.4.3), [['bar', '~> 2.0']]),
            @bf.create_specs('bar', %w(2.0.3)),
          ]
          @source_specs = [
            @bf.create_specs('foo', %w(1.4.3 1.4.4), [['bar', '~> 2.0']]),
            @bf.create_specs('foo', %w(1.4.5 1.5.0), [['bar', '~> 2.1']]),
            @bf.create_specs('foo', %w(1.5.1), [['bar', '~> 3.0']]),
            @bf.create_specs('bar', %w(2.0.3 2.0.4 2.1.0 2.1.1 3.0.0)),
          ]
        end

        it 'bundle update --patch' do
          Dir.chdir(@bf.dir) do
            test_it

            lockfile_spec_version('foo').should == '1.4.5'
            lockfile_spec_version('bar').should == '2.1.1'
          end
        end

        it 'bundle update --patch foo' do
          Dir.chdir(@bf.dir) do
            test_it(gems: 'foo')

            lockfile_spec_version('foo').should == '1.4.5'
            lockfile_spec_version('bar').should == '2.1.1'
          end
        end

        it 'bundle update --minor' do
          Dir.chdir(@bf.dir) do
            test_it(options: {minor: true})

            lockfile_spec_version('foo').should == '1.5.1'
            lockfile_spec_version('bar').should == '3.0.0'
          end
        end

        it 'bundle update --minor --strict' do
          Dir.chdir(@bf.dir) do
            test_it(options: {minor: true, strict: true})

            lockfile_spec_version('foo').should == '1.5.0'
            lockfile_spec_version('bar').should == '2.1.1'
          end
        end

        it 'bundle update --patch --strict' do
          Dir.chdir(@bf.dir) do
            test_it(options: {minor: false, strict: true})

            lockfile_spec_version('foo').should == '1.4.4'
            lockfile_spec_version('bar').should == '2.0.4'
          end
        end
      end

      context 'Shared Dependencies' do
        context 'Cannot Move' do
          before do
            @gem_deps = [@bf.create_dependency('foo'), @bf.create_dependency('qux')]
            @lock_source_specs = [
              @bf.create_specs('foo', %w(1.4.3), [['shared', '~> 2.0'], ['bar', '~> 2.0']]),
              @bf.create_specs('qux', %w(1.0.0), [['shared', '~> 2.0.0']]),
              @bf.create_specs('bar', %w(2.0.3)),
              @bf.create_specs('shared', %w(2.0.3)),
            ]
            @source_specs = [
              @bf.create_specs('foo', %w(1.4.3 1.4.4), [['shared', '~> 2.0'], ['bar', '~> 2.0']]),
              @bf.create_specs('foo', %w(1.4.5 1.5.0), [['shared', '~> 2.1'], ['bar', '~> 2.1']]),
              @bf.create_specs('qux', %w(1.0.0), [['shared', '~> 2.0.0']]),
              @bf.create_specs('bar', %w(2.0.3 2.0.4 2.1.0 2.1.1)),
              @bf.create_specs('shared', %w(2.0.3 2.0.4 2.1.0 2.1.1)),
            ]
          end

          it 'bundle update --patch foo' do
            Dir.chdir(@bf.dir) do
              test_it(gems: ['foo'])

              lockfile_spec_version('foo').should == '1.4.4' #'1.4.5'
              lockfile_spec_version('bar').should == '2.0.3' #'2.1.1'
              lockfile_spec_version('qux').should == '1.0.0' #'1.0.0'
              lockfile_spec_version('shared').should == '2.0.3' #'2.0.3'
            end
          end

          it 'bundle update --patch foo bar' do
            Dir.chdir(@bf.dir) do
              test_it(gems: ['foo', 'bar'])

              lockfile_spec_version('foo').should == '1.4.4' #'1.4.5'
              lockfile_spec_version('bar').should == '2.0.4' #'2.1.1'
              lockfile_spec_version('qux').should == '1.0.0' #'1.0.0'
              lockfile_spec_version('shared').should == '2.0.3' #'2.0.3'
            end
          end

          it 'bundle update --patch' do
            Dir.chdir(@bf.dir) do
              test_it

              lockfile_spec_version('foo').should == '1.4.4' #'1.4.5'
              lockfile_spec_version('bar').should == '2.0.4' #'2.1.1'
              lockfile_spec_version('qux').should == '1.0.0' #'1.0.0'
              lockfile_spec_version('shared').should == '2.0.4' #'2.0.3'
            end
          end
        end

        # Almost identical, but dependency between qux and shared is more flexible
        context 'Can Move' do
          before do
            @gem_deps = [@bf.create_dependency('foo'), @bf.create_dependency('qux')]
            @lock_source_specs = [
              @bf.create_specs('foo', %w(1.4.3), [['shared', '~> 2.0'], ['bar', '~> 2.0']]),
              @bf.create_specs('qux', %w(1.0.0), [['shared', '~> 2.0']]),
              @bf.create_specs('bar', %w(2.0.3)),
              @bf.create_specs('shared', %w(2.0.3)),
            ]
            @source_specs = [
              @bf.create_specs('foo', %w(1.4.3 1.4.4), [['shared', '~> 2.0'], ['bar', '~> 2.0']]),
              @bf.create_specs('foo', %w(1.4.5 1.5.0), [['shared', '~> 2.1'], ['bar', '~> 2.1']]),
              @bf.create_specs('qux', %w(1.0.0), [['shared', '~> 2.0']]),
              @bf.create_specs('bar', %w(2.0.3 2.0.4 2.1.0 2.1.1)),
              @bf.create_specs('shared', %w(2.0.3 2.0.4 2.1.0 2.1.1)),
            ]
          end

          it 'bundle update --patch foo' do
            Dir.chdir(@bf.dir) do
              test_it(gems: ['foo'])

              lockfile_spec_version('foo').should == '1.4.5'
              lockfile_spec_version('bar').should == '2.1.1'
              lockfile_spec_version('qux').should == '1.0.0'
              lockfile_spec_version('shared').should == '2.1.1'
            end
          end

          it 'bundle update --patch foo bar' do
            Dir.chdir(@bf.dir) do
              test_it(gems: ['foo', 'bar'])

              lockfile_spec_version('foo').should == '1.4.5'
              lockfile_spec_version('bar').should == '2.1.1'
              lockfile_spec_version('qux').should == '1.0.0'
              lockfile_spec_version('shared').should == '2.1.1'
            end
          end

          it 'bundle update --patch' do
            Dir.chdir(@bf.dir) do
              test_it

              lockfile_spec_version('foo').should == '1.4.5'
              lockfile_spec_version('bar').should == '2.1.1'
              lockfile_spec_version('qux').should == '1.0.0'
              lockfile_spec_version('shared').should == '2.1.1'
            end
          end
        end
      end
    end
  end
end
