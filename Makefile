FLUTTER := ./tool/flutterw

.PHONY: run verify build-android build-ios
run:
	$(FLUTTER) run

verify:
	$(FLUTTER) analyze --no-pub
	$(FLUTTER) test --no-pub

build-android:
	$(FLUTTER) build apk --debug --no-pub

build-ios:
	$(FLUTTER) build ios --debug --no-codesign --no-pub
