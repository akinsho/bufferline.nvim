# Changelog

## [4.9.1](https://github.com/akinsho/bufferline.nvim/compare/v4.9.0...v4.9.1) (2025-01-14)


### Bug Fixes

* **utils:** correctly check for showing buffer icons ([1363a05](https://github.com/akinsho/bufferline.nvim/commit/1363a05043f1bca8012b979474fd35936f264d7c))

## [4.9.0](https://github.com/akinsho/bufferline.nvim/compare/v4.8.0...v4.9.0) (2024-10-24)


### Features

* **pick:** add config option for pick alphabet ([#972](https://github.com/akinsho/bufferline.nvim/issues/972)) ([5cc447c](https://github.com/akinsho/bufferline.nvim/commit/5cc447cb2b463cb499c82eaeabbed4f5fa6a0a44))

## [4.8.0](https://github.com/akinsho/bufferline.nvim/compare/v4.7.0...v4.8.0) (2024-10-22)


### Features

* **tabpages:** pass the bufnr to the `name_formatter` ([#941](https://github.com/akinsho/bufferline.nvim/issues/941)) ([28e347d](https://github.com/akinsho/bufferline.nvim/commit/28e347dbc6d0e8367ea56fb045fb9d135579ff79))

## [4.7.0](https://github.com/akinsho/bufferline.nvim/compare/v4.6.1...v4.7.0) (2024-07-10)


### Features

* **diag:** add `diagnostics_update_on_event` option ([#932](https://github.com/akinsho/bufferline.nvim/issues/932)) ([aa16daf](https://github.com/akinsho/bufferline.nvim/commit/aa16dafdc642594c7ade7e88d31a6119feb189d6))


### Bug Fixes

* **tabs:** use custom separator_style in tabpages ([#852](https://github.com/akinsho/bufferline.nvim/issues/852)) ([81820ca](https://github.com/akinsho/bufferline.nvim/commit/81820cac7c85e51e4cf179f8a66d13dbf7b032d9))
* UNKNOWN PLUGIN error resulting from unloaded buffers ([#928](https://github.com/akinsho/bufferline.nvim/issues/928)) ([6ac7e4f](https://github.com/akinsho/bufferline.nvim/commit/6ac7e4f1eead72507cfdbc94dcd0c26b98b2f86e))
* UNKNOWN PLUGIN error resulting from unloaded buffers ([#931](https://github.com/akinsho/bufferline.nvim/issues/931)) ([1662fed](https://github.com/akinsho/bufferline.nvim/commit/1662fed6ecd512d1f381fc2a4e77532c379d25c6))


### Reverts

* remove fix for referencing unloaded buffers ([#930](https://github.com/akinsho/bufferline.nvim/issues/930)) ([46192e7](https://github.com/akinsho/bufferline.nvim/commit/46192e794b73f92136326c10ecdbdbf15e35705f))

## [4.6.1](https://github.com/akinsho/bufferline.nvim/compare/v4.6.0...v4.6.1) (2024-05-21)


### Bug Fixes

* replace tbl_flatten to flatten():totable() ([#912](https://github.com/akinsho/bufferline.nvim/issues/912)) ([b2dc003](https://github.com/akinsho/bufferline.nvim/commit/b2dc003aca1dc638ccc3e7752ab3969b4184a690))

## [4.6.0](https://github.com/akinsho/bufferline.nvim/compare/v4.5.3...v4.6.0) (2024-05-20)


### Features

* add `auto_toggle_bufferline` option ([#876](https://github.com/akinsho/bufferline.nvim/issues/876)) ([f6f00d9](https://github.com/akinsho/bufferline.nvim/commit/f6f00d9ac1a51483ac78418f9e63126119a70709))


### Bug Fixes

* maintain backwards compatibility ([#909](https://github.com/akinsho/bufferline.nvim/issues/909)) ([155b257](https://github.com/akinsho/bufferline.nvim/commit/155b257b0c1d7999b0ffc837e1dd3a110cdc33d0))
* reimplement the deprecated function tbl_add_reverse_lookup ([#904](https://github.com/akinsho/bufferline.nvim/issues/904)) ([9ae49d7](https://github.com/akinsho/bufferline.nvim/commit/9ae49d71c84b42b91795f7b7cead223c6346e774))
* **utils:** update is_list to handle breaking change ([#892](https://github.com/akinsho/bufferline.nvim/issues/892)) ([a6ad228](https://github.com/akinsho/bufferline.nvim/commit/a6ad228f77c276a4324924a6899cbfad70541547))
* vim.diagnostic.is_disabled() deprecation warning ([#907](https://github.com/akinsho/bufferline.nvim/issues/907)) ([2cd3984](https://github.com/akinsho/bufferline.nvim/commit/2cd39842c6426fb6c9a79fa57420121cc81c9804))

## [4.5.3](https://github.com/akinsho/bufferline.nvim/compare/v4.5.2...v4.5.3) (2024-04-19)


### Bug Fixes

* **utils:** improve path separator detection on Windows ([#888](https://github.com/akinsho/bufferline.nvim/issues/888)) ([d7ebc0d](https://github.com/akinsho/bufferline.nvim/commit/d7ebc0de62a2f752dcd3cadf6f3235a0702f15a3))

## [4.5.2](https://github.com/akinsho/bufferline.nvim/compare/v4.5.1...v4.5.2) (2024-03-07)


### Bug Fixes

* **tabpages:** renaming bug on reopened tab ([#877](https://github.com/akinsho/bufferline.nvim/issues/877)) ([1064399](https://github.com/akinsho/bufferline.nvim/commit/10643990c33ca295bfe970d775c6e7697354aa0f))

## [4.5.1](https://github.com/akinsho/bufferline.nvim/compare/v4.5.0...v4.5.1) (2024-03-05)


### Bug Fixes

* **tabpages:** typo in rename_tab ([#873](https://github.com/akinsho/bufferline.nvim/issues/873)) ([5bf13d1](https://github.com/akinsho/bufferline.nvim/commit/5bf13d17a8c8abbce8d3ef83c8658b32e08ce913))

## [4.5.0](https://github.com/akinsho/bufferline.nvim/compare/v4.4.1...v4.5.0) (2024-01-22)


### Features

* **ui:** tab renaming ([#848](https://github.com/akinsho/bufferline.nvim/issues/848)) ([f2e6c86](https://github.com/akinsho/bufferline.nvim/commit/f2e6c86975deb0f4594d671b7f31c379802491d3))


### Bug Fixes

* skip invalid regex in truncate_name ([#841](https://github.com/akinsho/bufferline.nvim/issues/841)) ([ac788fb](https://github.com/akinsho/bufferline.nvim/commit/ac788fbc493839c1e76daa8d119934b715fdb90e))

## [4.4.1](https://github.com/akinsho/bufferline.nvim/compare/v4.4.0...v4.4.1) (2023-12-06)


### Bug Fixes

* **commands:** potential nil access ([#821](https://github.com/akinsho/bufferline.nvim/issues/821)) ([6e96fa2](https://github.com/akinsho/bufferline.nvim/commit/6e96fa27a0d4dd6c00a252b51c0b43b9b95cd302))
* remove `missing required fields` diagnostic from config ([#812](https://github.com/akinsho/bufferline.nvim/issues/812)) ([1a33975](https://github.com/akinsho/bufferline.nvim/commit/1a3397556d194bb1f2cc530b07124ccc512c5501))
* use link if specified in custom areas ([#839](https://github.com/akinsho/bufferline.nvim/issues/839)) ([9ca364d](https://github.com/akinsho/bufferline.nvim/commit/9ca364d488b98894ca780c40aae9ea63967c8fcf))

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
