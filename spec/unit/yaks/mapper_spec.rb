require 'spec_helper'

describe Yaks::Mapper do
  subject(:mapper)       { mapper_class.new(instance, policy) }

  let(:mapper_class) { Class.new(Yaks::Mapper) { type 'foo' } }
  let(:instance)     { double(foo: 'hello', bar: 'world') }
  let(:policy)       { nil }
  let(:options)      { {} }


  describe '#map_attributes' do
    before do
      mapper_class.attributes :foo, :bar
    end

    it 'should make the configured attributes available on the instance' do
      expect(mapper.attributes).to eq [:foo, :bar]
    end

    it 'should load them from the model' do
      expect(mapper.map_attributes).to eq(foo: 'hello', bar: 'world')
    end

    context 'with attribute filtering' do
      before do
        mapper_class.class_eval do
          def filter(attrs)
            attrs.to_a - [:foo]
          end
        end
      end

      it 'should only map the non-filtered attributes' do
        expect(mapper.map_attributes).to eq(:bar => 'world')
      end
    end
  end

  describe '#map_links' do
    before do
      mapper_class.link :profile, 'http://foo/bar'
    end

    it 'should map the link' do
      expect(mapper.map_links).to eq [
        Yaks::Resource::Link.new(:profile, 'http://foo/bar', {})
      ]
    end

    it 'should use the link in the resource' do
      expect(mapper.to_resource.links).to include Yaks::Resource::Link.new(:profile, 'http://foo/bar', {})
    end
  end

  describe '#map_subresources' do
    let(:instance)      { double(widget: widget) }
    let(:widget)        { double(type: 'super_widget') }
    let(:widget_mapper) { Class.new(Yaks::Mapper) { type 'widget' } }
    let(:policy)        { double('Policy') }

    describe 'has_one' do
      let(:has_one_opts) do
        { mapper: widget_mapper,
          rel: 'http://foo.bar/rels/widgets' }
      end

      before do
        widget_mapper.attributes :type
        mapper_class.has_one(:widget, has_one_opts)
      end


      it 'should have the subresource in the resource' do
        expect(mapper.to_resource.subresources).to eq("http://foo.bar/rels/widgets" => Yaks::Resource.new(type: 'widget', attributes: {:type => "super_widget"}))
      end

      context 'with explicit mapper and rel' do
        it 'should delegate to the given mapper' do
          expect(mapper.map_subresources).to eq(
            "http://foo.bar/rels/widgets" => Yaks::Resource.new(type: 'widget', attributes: {:type => "super_widget"})
          )
        end
      end

      context 'with unspecified mapper' do
        let(:has_one_opts) do
          { rel: 'http://foo.bar/rels/widgets' }
        end

        it 'should derive the mapper based on policy' do
          expect(policy).to receive(:derive_mapper_from_association) {|assoc|
            expect(assoc).to be_a Yaks::Mapper::HasOne
            widget_mapper
          }
          expect(mapper.map_subresources).to eq(
            "http://foo.bar/rels/widgets" => Yaks::Resource.new(type: 'widget', attributes: {:type => "super_widget"})
          )
        end
      end

      context 'with unspecified rel' do
        let(:has_one_opts) do
          { mapper: widget_mapper }
        end

        it 'should derive the rel based on policy' do
          expect(policy).to receive(:derive_rel_from_association) {|parent_mapper, assoc|
            expect(parent_mapper).to equal mapper
            expect(assoc).to be_a Yaks::Mapper::HasOne
            'http://rel/rel'
          }
          expect(mapper.map_subresources).to eq(
            "http://rel/rel" => Yaks::Resource.new(type: 'widget', attributes: {:type => "super_widget"})
          )
        end
      end

      context 'with the association filtered out' do
        before do
          mapper_class.class_eval do
            def filter(attrs) [] end
          end
        end

        it 'should not map the resource' do
          expect(mapper.map_subresources).to eq({})
        end
      end
    end
  end

  describe '#load_attributes' do
    context 'when the mapper implements a method with the attribute name' do
      before do
        mapper_class.class_eval do
          attributes :fooattr, :bar

          def fooattr
            "#{object.foo} my friend"
          end
        end
      end

      it 'should get the attribute from the mapper' do
        expect(mapper.map_attributes).to eq(fooattr: 'hello my friend', bar: 'world')
      end
    end
  end

  describe '#to_resource' do
    let(:instance) { nil }

    it 'should return a NullResource when the subject is nil' do
      expect(mapper.to_resource).to be_a Yaks::NullResource
    end
  end
end