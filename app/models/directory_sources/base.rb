module DirectorySources
  class Base
    # Sources yield external_id, name, email, and phone; optional skills replaces local tags only when supplied.
    def each_person
      raise Error, "This directory source is not implemented."
    end
  end
end
