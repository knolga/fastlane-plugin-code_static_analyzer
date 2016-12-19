describe Fastlane::Actions::CodeStaticAnalyzerAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The code_static_analyzer plugin is working!")

      Fastlane::Actions::CodeStaticAnalyzerAction.run(nil)
    end
  end
end
