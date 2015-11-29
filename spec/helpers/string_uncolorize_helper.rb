class String
  REGEXP_PATTERN = /(\e|\033)\[(\d+?)(;\d+?)*m/m

  def uncolorize
    self.gsub(REGEXP_PATTERN, '')
  end
end