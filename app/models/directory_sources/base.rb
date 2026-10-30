module DirectorySources
  class Base
    # Sources yield hashes with exactly external_id, name, email, and phone keys.
    def each_person
      raise Error, "This directory source is not implemented."
    end
  end
end
