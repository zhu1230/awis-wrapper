class AwisWrapper
  module Version
    MAJOR = 3
    MINOR = 0
    PATCH = 0
    BUILD = ''

    STRING = [MAJOR, MINOR, PATCH, BUILD].compact.join('.')
  end
end