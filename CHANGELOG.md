# Changelog

## [4.4.0](https://github.com/akinsho/bufferline.nvim/compare/v4.3.0...v4.4.0) (2023-09-20)


### Features

* Support `name_formatter` for unnamed buffers ([#806](https://github.com/akinsho/bufferline.nvim/issues/806)) ([9961d87](https://github.com/akinsho/bufferline.nvim/commit/9961d87bb3ec008213c46ba14b3f384a5f520eb5))


### Bug Fixes

* **diagnostics:** ignore disabled diagnostics ([#816](https://github.com/akinsho/bufferline.nvim/issues/816)) ([8a51c4b](https://github.com/akinsho/bufferline.nvim/commit/8a51c4b5d105d93fd2bc435bf93d4d5556fb2a60))
* **icons:** display overriden devicons ([#817](https://github.com/akinsho/bufferline.nvim/issues/817)) ([81cd04f](https://github.com/akinsho/bufferline.nvim/commit/81cd04fe7c914d020d331cea1e707da5f14c2665))
* **readme:** Typo ([#793](https://github.com/akinsho/bufferline.nvim/issues/793)) ([99f0932](https://github.com/akinsho/bufferline.nvim/commit/99f0932365b34e22549ff58e1bea388465d15e99))

## [4.3.0](https://github.com/akinsho/bufferline.nvim/compare/v4.2.0...v4.3.0) (2023-07-17)


### Features

* **command:** add BufferLineCloseOthers command ([#774](https://github.com/akinsho/bufferline.nvim/issues/774)) ([9d6ab3a](https://github.com/akinsho/bufferline.nvim/commit/9d6ab3a56ad71bed9929c7acd7620e827a073d25))
* **ui:** trunc marker highlights ([#781](https://github.com/akinsho/bufferline.nvim/issues/781)) ([77779e3](https://github.com/akinsho/bufferline.nvim/commit/77779e34d673dd41244b710c22fb18bbfa4c455f)), closes [#792](https://github.com/akinsho/bufferline.nvim/issues/792)


### Bug Fixes

* **config:** highlighting for tab separators ([#784](https://github.com/akinsho/bufferline.nvim/issues/784)) ([cd27a52](https://github.com/akinsho/bufferline.nvim/commit/cd27a52ecdfed7f14a41b61b7976f155e3d593c7))
* store paths in g:BufferlinePositions ([#780](https://github.com/akinsho/bufferline.nvim/issues/780)) ([2f391fd](https://github.com/akinsho/bufferline.nvim/commit/2f391fde91b9c3876eee359ee24cc352050e5e48))
* **ui:** always schedule refreshing ([fe77474](https://github.com/akinsho/bufferline.nvim/commit/fe774743cc7434d8f5539093108bf7d6d950f416))

## [4.2.0](https://github.com/akinsho/bufferline.nvim/compare/v4.1.0...v4.2.0) (2023-06-26)


### Features

* **commands/go_to:** go to the last element if index out of bounds ([#758](https://github.com/akinsho/bufferline.nvim/issues/758)) ([6073426](https://github.com/akinsho/bufferline.nvim/commit/60734264a8655a7db3595159fb50076dc24c2f2c))
* **commands:** add option to wrap when moving buffers at ends ([#759](https://github.com/akinsho/bufferline.nvim/issues/759)) ([da1875c](https://github.com/akinsho/bufferline.nvim/commit/da1875c1eee9aa9b7e19cda5c70ed7d7702d5f06))


### Performance Improvements

* **ui:** avoid (some) expensive functions ([#754](https://github.com/akinsho/bufferline.nvim/issues/754)) ([018bdf6](https://github.com/akinsho/bufferline.nvim/commit/018bdf61a97e00caeff05d16977437c63018762e))

## [4.1.0](https://github.com/akinsho/bufferline.nvim/compare/v4.0.0...v4.1.0) (2023-05-03)


### Features

* **ui:** add `padded_slope` style ([#739](https://github.com/akinsho/bufferline.nvim/issues/739)) ([f336811](https://github.com/akinsho/bufferline.nvim/commit/f336811168e04362dfceb51b7e992dfd6ae4e78e))


### Bug Fixes

* **docs:** use correct value for style presets ([#747](https://github.com/akinsho/bufferline.nvim/issues/747)) ([9eed863](https://github.com/akinsho/bufferline.nvim/commit/9eed86350dcb4a5cca13056d0d16ba85e20e5024))
* **groups:** use correct cmdline completion function ([a4bd445](https://github.com/akinsho/bufferline.nvim/commit/a4bd44523316928a7c4a5c09a3407d02c30b6027))

## [4.0.0](https://github.com/akinsho/bufferline.nvim/compare/v3.7.0...v4.0.0) (2023-04-23)


### ⚠ BREAKING CHANGES

* **groups:** change argument to group matcher
* **config:** deprecate show_buffer_default_icon

### Features

* **colors:** add diagnostic underline fallback ([bd9915f](https://github.com/akinsho/bufferline.nvim/commit/bd9915fa13f53176fe3a4a943e3f95c7e4312e50))
* **config:** allow specifying style presets ([13cb114](https://github.com/akinsho/bufferline.nvim/commit/13cb114e91c17238aaa271746aaeb8e967f350a2))
* **diag:** sane fallback to underline color ([0cd505b](https://github.com/akinsho/bufferline.nvim/commit/0cd505b333151e883cdd854539e5eae0e4f3e339))


### Bug Fixes

* **color:** follow linked hl groups ([e6e7cc4](https://github.com/akinsho/bufferline.nvim/commit/e6e7cc454fa28304246e97a9acfe7c6cf2adc5d6))
* **highlights:** if color_icons is false set to NONE ([8b32447](https://github.com/akinsho/bufferline.nvim/commit/8b32447f1ba00f71ec2ebb413249d1d84228d9fb)), closes [#702](https://github.com/akinsho/bufferline.nvim/issues/702)
* **sorters:** insert_after_current strategy ([1620cfe](https://github.com/akinsho/bufferline.nvim/commit/1620cfe8f226b49bfc4886a092449f565b4d84ab))


### Code Refactoring

* **config:** deprecate show_buffer_default_icon ([6ccdee8](https://github.com/akinsho/bufferline.nvim/commit/6ccdee8e931503699eb8f92c7faafd0ad1a8cf69))
* **groups:** change argument to group matcher ([38d62b8](https://github.com/akinsho/bufferline.nvim/commit/38d62b8bae62c681d6e259de54421d4155976897))

## [3.7.0](https://github.com/akinsho/bufferline.nvim/compare/v3.6.0...v3.7.0) (2023-04-15)


### Features

* **groups:** close and unpin ([#698](https://github.com/akinsho/bufferline.nvim/issues/698)) ([52241b5](https://github.com/akinsho/bufferline.nvim/commit/52241b57ed41c2283020c6c79ef48fc7cd808bea))


### Bug Fixes

* **ui:** Use correct function to check for list ([#726](https://github.com/akinsho/bufferline.nvim/issues/726)) ([dd86c31](https://github.com/akinsho/bufferline.nvim/commit/dd86c312fd225549ac02567d47570c04ba456402))
* **utils:** fix utils.is_list ([#728](https://github.com/akinsho/bufferline.nvim/issues/728)) ([2c8d615](https://github.com/akinsho/bufferline.nvim/commit/2c8d615c47a5013b24b3b4bdebec2fda1b38cdd9))
